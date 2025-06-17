#!/bin/bash
# Simple deployment script for Mail-Rulez
# No environment variables or configuration files required

set -e

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

# Configuration
COMPOSE_FILE="docker-compose.simple.yml"
CONTAINER_NAME="mail-rulez-simple"
SERVICE_NAME="mail-rulez"

log_info "=== Mail-Rulez Simple Deployment ==="
log_info "Starting self-contained deployment..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not available"
    exit 1
fi

# Determine docker-compose command
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

log_info "Using Docker Compose: $DOCKER_COMPOSE"

# Check if we're in the correct directory
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Cannot find $COMPOSE_FILE in current directory"
    log_error "Please run this script from the docker/ directory"
    exit 1
fi

# Clean up any existing containers
log_info "Cleaning up existing containers..."
$DOCKER_COMPOSE -f $COMPOSE_FILE down --remove-orphans 2>/dev/null || true
docker rm -f $CONTAINER_NAME 2>/dev/null || true

# Build and start the container
log_info "Building Mail-Rulez container..."
$DOCKER_COMPOSE -f $COMPOSE_FILE build --no-cache

log_info "Starting Mail-Rulez container..."
$DOCKER_COMPOSE -f $COMPOSE_FILE up -d

# Wait for container to be ready
log_info "Waiting for container to start..."
sleep 10

# Check container status
if docker ps | grep -q $CONTAINER_NAME; then
    log_info "✓ Container $CONTAINER_NAME is running"
    
    # Show container logs for verification
    log_info "Container startup logs:"
    docker logs $CONTAINER_NAME --tail 20
    
    # Test if the service is responding
    log_info "Testing service availability..."
    sleep 5
    
    if curl -f -s "http://localhost:5001/auth/session/status" > /dev/null 2>&1; then
        log_info "✓ Mail-Rulez is responding on http://localhost:5001"
        log_info ""
        log_info "=== Deployment Successful ==="
        log_info "Access your Mail-Rulez instance at: http://localhost:5001"
        log_info "- No initial configuration required"
        log_info "- Secure keys generated automatically"
        log_info "- All data stored in Docker volumes"
        log_info ""
        log_info "Management commands:"
        log_info "  View logs: docker logs $CONTAINER_NAME"
        log_info "  Stop:      $DOCKER_COMPOSE -f $COMPOSE_FILE down"
        log_info "  Restart:   $DOCKER_COMPOSE -f $COMPOSE_FILE restart"
    else
        log_warn "Container is running but service not yet ready"
        log_warn "Check logs: docker logs $CONTAINER_NAME"
        log_warn "Service should be available at http://localhost:5001 shortly"
    fi
else
    log_error "✗ Container failed to start"
    log_error "Check the logs:"
    docker logs $CONTAINER_NAME 2>/dev/null || echo "No logs available"
    exit 1
fi