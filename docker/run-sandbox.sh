#!/bin/bash
# Mail-Rulez Sandbox Runner
# Sets up a containerized Mail-Rulez instance for manual testing, UAT, and development

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
DEFAULT_PORT=5001
DEFAULT_IMAGE_TYPE="development"
DEFAULT_SANDBOX_DIR="$PROJECT_ROOT/sandbox"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
Mail-Rulez Sandbox Runner

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    start       Start the sandbox container (default)
    stop        Stop the sandbox container
    restart     Restart the sandbox container
    logs        Show container logs
    shell       Open interactive shell in container
    status      Show container status
    clean       Stop and remove container and volumes
    rebuild     Rebuild image and restart container

OPTIONS:
    -h, --help              Show this help message
    -p, --port PORT         Host port to bind (default: 5001)
    -t, --type TYPE         Image type: development|production (default: development)
    -n, --name NAME         Container name (default: mail-rulez-sandbox)
    -d, --detach            Run in background (default for start)
    -f, --foreground        Run in foreground with logs
    --data-dir DIR          Custom data directory (default: ./sandbox)
    --rebuild               Force rebuild image before starting
    --clean-start           Clean existing container before starting
    --debug                 Enable debug output
    --no-setup              Skip initial setup wizard
    --mock-email            Use mock email server for testing

EXAMPLES:
    # Start sandbox with default settings
    $0 start

    # Start on custom port in foreground
    $0 start --port 8080 --foreground

    # Start production image
    $0 start --type production

    # Open interactive shell
    $0 shell

    # View logs
    $0 logs

    # Clean restart
    $0 restart --clean-start

    # Development mode with debugging
    $0 start --type development --debug --foreground

ACCESS:
    Once started, access Mail-Rulez at:
    - Web Interface: http://localhost:5001
    - Health Check: http://localhost:5001/health
    - API Status: http://localhost:5001/api/status

EOF
}

# Parse command line arguments
COMMAND="start"
PORT=$DEFAULT_PORT
IMAGE_TYPE=$DEFAULT_IMAGE_TYPE
CONTAINER_NAME="mail-rulez-sandbox"
DETACH=true
SANDBOX_DIR=$DEFAULT_SANDBOX_DIR
REBUILD=false
CLEAN_START=false
DEBUG=false
NO_SETUP=false
MOCK_EMAIL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        start|stop|restart|logs|shell|status|clean|rebuild)
            COMMAND="$1"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--type)
            IMAGE_TYPE="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        -f|--foreground)
            DETACH=false
            shift
            ;;
        --data-dir)
            SANDBOX_DIR="$2"
            shift 2
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        --clean-start)
            CLEAN_START=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --no-setup)
            NO_SETUP=true
            shift
            ;;
        --mock-email)
            MOCK_EMAIL=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set debug environment
if [ "$DEBUG" = "true" ]; then
    export DEBUG=true
    set -x
fi

# Validate image type
if [[ "$IMAGE_TYPE" != "development" && "$IMAGE_TYPE" != "production" ]]; then
    log_error "Invalid image type: $IMAGE_TYPE. Must be 'development' or 'production'"
    exit 1
fi

# Set image name based on type
if [ "$IMAGE_TYPE" = "production" ]; then
    IMAGE_NAME="mail-rulez:prod"
    DOCKERFILE_TARGET="production"
else
    IMAGE_NAME="mail-rulez:dev"
    DOCKERFILE_TARGET="development"
fi

# Function to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Function to build image if needed
build_image() {
    if [ "$REBUILD" = "true" ] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        log_info "Building $IMAGE_TYPE image..."
        if docker build --network=host \
            -f "$SCRIPT_DIR/Dockerfile" \
            --target "$DOCKERFILE_TARGET" \
            -t "$IMAGE_NAME" \
            "$PROJECT_ROOT"; then
            log_info "$IMAGE_TYPE image built successfully"
        else
            log_error "Failed to build $IMAGE_TYPE image"
            exit 1
        fi
    else
        log_debug "Using existing $IMAGE_TYPE image"
    fi
}

# Function to setup sandbox directories
setup_sandbox() {
    log_info "Setting up sandbox environment in: $SANDBOX_DIR"
    
    # Create directory structure
    mkdir -p "$SANDBOX_DIR"/{data,lists,logs,config,backups}
    
    # Create sample list files
    cat > "$SANDBOX_DIR/lists/white.txt" << EOF
# Whitelist - Trusted senders (automatically processed)
friend@example.com
newsletter@trusted-company.com
support@known-service.com
EOF

    cat > "$SANDBOX_DIR/lists/black.txt" << EOF
# Blacklist - Blocked senders (sent to junk)
spam@badsite.com
noreply@suspicious-domain.com
EOF

    cat > "$SANDBOX_DIR/lists/vendor.txt" << EOF
# Vendor list - Commercial emails (sent to approved ads folder)
marketing@retailer.com
promotions@store.com
deals@shopping-site.com
EOF

    # Create sample configuration if it doesn't exist
    if [ ! -f "$SANDBOX_DIR/config/accounts.json" ] && [ "$NO_SETUP" = "false" ]; then
        cat > "$SANDBOX_DIR/config/accounts.json" << EOF
{
    "accounts": [
        {
            "name": "sandbox_account",
            "server": "imap.example.com",
            "email": "sandbox@example.com",
            "password": "ENCRYPTED_PASSWORD_HERE",
            "folders": {
                "inbox": "INBOX",
                "processed": "INBOX.Processed",
                "pending": "INBOX.Pending",
                "junk": "INBOX.Junk",
                "approved_ads": "INBOX.Approved_Ads",
                "headhunt": "INBOX.HeadHunt"
            }
        }
    ],
    "retention_settings": {
        "approved_ads": 30,
        "processed": 90,
        "pending": 365,
        "junk": 7
    }
}
EOF
        log_info "Created sample configuration file"
        log_warn "Edit $SANDBOX_DIR/config/accounts.json with your email settings"
    fi

    # Set permissions
    chmod -R 755 "$SANDBOX_DIR"
    
    log_info "Sandbox environment ready"
}

# Function to start container
start_container() {
    build_image
    setup_sandbox
    
    if [ "$CLEAN_START" = "true" ] && container_exists; then
        log_info "Cleaning existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    if container_running; then
        log_warn "Container $CONTAINER_NAME is already running"
        log_info "Access Mail-Rulez at: http://localhost:$PORT"
        return 0
    elif container_exists; then
        log_info "Starting existing container..."
        docker start "$CONTAINER_NAME"
    else
        log_info "Creating and starting new container..."
        
        # Build Docker run command
        DOCKER_CMD="docker run"
        
        if [ "$DETACH" = "true" ]; then
            DOCKER_CMD="$DOCKER_CMD -d"
        else
            DOCKER_CMD="$DOCKER_CMD -it"
        fi
        
        # Environment variables
        ENV_VARS=(
            "-e FLASK_ENV=$IMAGE_TYPE"
            "-e FLASK_PORT=5001"
            "-e FLASK_SECRET_KEY=sandbox-secret-key-change-in-production"
            "-e MAIL_RULEZ_LOG_DIR=/app/logs"
            "-e MAIL_RULEZ_DATA_DIR=/app/data"
            "-e MAIL_RULEZ_LISTS_DIR=/app/lists"
            "-e MAIL_RULEZ_CONFIG_DIR=/app/config"
            "-e MAIL_RULEZ_BACKUPS_DIR=/app/backups"
            "-e MAIL_RULEZ_LOG_LEVEL=$([ "$DEBUG" = "true" ] && echo "DEBUG" || echo "INFO")"
            "-e MAIL_RULEZ_JSON_LOGS=false"
            "-e MAIL_RULEZ_SKIP_NETWORK_CHECK=true"
            "-e MAIL_RULEZ_STRICT_VALIDATION=false"
        )
        
        if [ "$MOCK_EMAIL" = "true" ]; then
            ENV_VARS+=("-e MAIL_RULEZ_MOCK_EMAIL=true")
        fi
        
        # Volume mounts
        VOLUMES=(
            "-v $SANDBOX_DIR/data:/app/data"
            "-v $SANDBOX_DIR/lists:/app/lists"
            "-v $SANDBOX_DIR/logs:/app/logs"
            "-v $SANDBOX_DIR/config:/app/config"
            "-v $SANDBOX_DIR/backups:/app/backups"
        )
        
        # Port mapping
        PORT_MAP="-p $PORT:5001"
        
        # Container name and restart policy
        CONTAINER_OPTS="--name $CONTAINER_NAME --restart unless-stopped"
        
        # Health check
        HEALTH_CHECK="--health-cmd 'curl -f http://localhost:5001/health || exit 1' --health-interval=30s --health-timeout=10s --health-retries=3"
        
        # Execute docker run
        eval "$DOCKER_CMD $CONTAINER_OPTS $PORT_MAP ${ENV_VARS[*]} ${VOLUMES[*]} $HEALTH_CHECK $IMAGE_NAME"
    fi
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    for i in {1..30}; do
        if curl -s "http://localhost:$PORT/health" >/dev/null 2>&1; then
            break
        elif [ $i -eq 30 ]; then
            log_warn "Container may not be fully ready yet"
            break
        else
            sleep 2
        fi
    done
    
    log_info "Mail-Rulez sandbox is running!"
    log_info ""
    log_info "Access URLs:"
    log_info "  🌐 Web Interface: http://localhost:$PORT"
    log_info "  ❤️  Health Check:  http://localhost:$PORT/health"
    log_info "  📊 Status API:    http://localhost:$PORT/api/status"
    log_info ""
    log_info "Sandbox Data: $SANDBOX_DIR"
    log_info "Container Name: $CONTAINER_NAME"
    log_info ""
    log_info "Quick Commands:"
    log_info "  View logs:  $0 logs"
    log_info "  Open shell: $0 shell"
    log_info "  Stop:       $0 stop"
    
    if [ "$DETACH" = "false" ]; then
        log_info ""
        log_info "Container running in foreground. Press Ctrl+C to stop."
        docker logs -f "$CONTAINER_NAME"
    fi
}

# Function to stop container
stop_container() {
    if container_running; then
        log_info "Stopping container..."
        docker stop "$CONTAINER_NAME"
        log_info "Container stopped"
    else
        log_warn "Container is not running"
    fi
}

# Function to restart container
restart_container() {
    if container_exists; then
        log_info "Restarting container..."
        docker restart "$CONTAINER_NAME"
        log_info "Container restarted"
        log_info "Access Mail-Rulez at: http://localhost:$PORT"
    else
        log_info "Container doesn't exist, creating new one..."
        start_container
    fi
}

# Function to show logs
show_logs() {
    if container_exists; then
        log_info "Showing container logs (Ctrl+C to exit)..."
        docker logs -f "$CONTAINER_NAME"
    else
        log_error "Container doesn't exist"
        exit 1
    fi
}

# Function to open shell
open_shell() {
    if container_running; then
        log_info "Opening interactive shell in container..."
        docker exec -it "$CONTAINER_NAME" bash
    elif container_exists; then
        log_info "Starting container and opening shell..."
        docker start "$CONTAINER_NAME"
        sleep 2
        docker exec -it "$CONTAINER_NAME" bash
    else
        log_error "Container doesn't exist. Start it first with: $0 start"
        exit 1
    fi
}

# Function to show status
show_status() {
    log_info "Container Status:"
    if container_exists; then
        docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
        
        if container_running; then
            log_info ""
            log_info "Health Status:"
            HEALTH=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
            echo "  Health: $HEALTH"
            
            log_info ""
            log_info "Resource Usage:"
            docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
            
            log_info ""
            log_info "Access URLs:"
            log_info "  🌐 Web Interface: http://localhost:$PORT"
            log_info "  ❤️  Health Check:  http://localhost:$PORT/health"
        fi
    else
        echo "Container does not exist"
    fi
}

# Function to clean everything
clean_all() {
    log_info "Cleaning up sandbox container and data..."
    
    # Stop and remove container
    if container_exists; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_info "Container removed"
    fi
    
    # Optionally clean sandbox data
    read -p "Do you want to remove sandbox data directory ($SANDBOX_DIR)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SANDBOX_DIR"
        log_info "Sandbox data removed"
    else
        log_info "Sandbox data preserved"
    fi
    
    log_info "Cleanup completed"
}

# Function to rebuild
rebuild_all() {
    log_info "Rebuilding image and restarting container..."
    REBUILD=true
    CLEAN_START=true
    start_container
}

# Execute command
case $COMMAND in
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    restart)
        restart_container
        ;;
    logs)
        show_logs
        ;;
    shell)
        open_shell
        ;;
    status)
        show_status
        ;;
    clean)
        clean_all
        ;;
    rebuild)
        rebuild_all
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac