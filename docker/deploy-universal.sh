#!/bin/bash
# Mail-Rulez Universal Deployment Script
# Compatible with Linux, macOS, Windows (Git Bash/WSL), and other Unix-like systems

set -e

echo "🚀 Mail-Rulez Universal Deployment"
echo "==================================="

# Detect operating system
OS="unknown"
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    CYGWIN*)    OS=Windows;;
    MINGW*)     OS=Windows;;
    MSYS*)      OS=Windows;;
    *)          OS="unknown";;
esac

echo "🖥️  Detected OS: $OS"

# Check if docker is available (cross-platform check)
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is not installed or not in PATH."
    echo "   Please install Docker Desktop (Windows/Mac) or Docker CE (Linux)"
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ Docker Compose is not installed or not in PATH."
    echo "   On newer Docker installations, try 'docker compose' instead"
    echo "   Or install docker-compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running."
    echo "   Please start Docker Desktop (Windows/Mac) or Docker service (Linux)"
    exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Create necessary directories (cross-platform)
echo "📁 Creating directories..."
mkdir -p data lists logs backups config

# Handle environment file setup
ENV_FILE=".env"
ENV_TEMPLATE=".env.secure"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_TEMPLATE" ]; then
        echo "📋 Creating $ENV_FILE from template..."
        cp "$ENV_TEMPLATE" "$ENV_FILE"
        echo "⚠️  IMPORTANT: Edit $ENV_FILE file and set:"
        echo "   - FLASK_SECRET_KEY (generate with: openssl rand -hex 32)"
        echo "   - MASTER_KEY (generate with: openssl rand -base64 32)"
        echo ""
        echo "   If openssl is not available, use any random string generator"
    else
        echo "📋 Creating basic $ENV_FILE..."
        cat > "$ENV_FILE" << EOF
# Mail-Rulez Configuration
PORT=5001
FLASK_SECRET_KEY=change-this-to-a-long-random-string-in-production
MASTER_KEY=generate-this-with-openssl-rand-base64-32
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30
STRICT_VALIDATION=true
SKIP_NETWORK_CHECK=false
EOF
        echo "⚠️  IMPORTANT: Edit $ENV_FILE and set secure keys!"
    fi
else
    echo "✅ Environment file $ENV_FILE already exists"
fi

# Use universal docker-compose file
COMPOSE_FILE="docker-compose.universal.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ $COMPOSE_FILE not found. Using docker-compose.yml as fallback."
    COMPOSE_FILE="docker-compose.yml"
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# Build and start the application
echo "🔨 Building Mail-Rulez container..."
docker-compose -f "$COMPOSE_FILE" build

echo "🚀 Starting Mail-Rulez..."
docker-compose -f "$COMPOSE_FILE" up -d

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 10

# Check if container is running
CONTAINER_STATUS=$(docker-compose -f "$COMPOSE_FILE" ps -q mail-rulez 2>/dev/null | wc -l)

if [ "$CONTAINER_STATUS" -gt 0 ]; then
    # Get the configured port
    PORT=$(grep "^PORT=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "5001")
    
    echo "✅ Mail-Rulez is running!"
    echo ""
    echo "🌐 Access URLs:"
    echo "   Local:    http://localhost:${PORT}"
    echo "   Network:  http://<your-ip>:${PORT}"
    echo ""
    echo "📊 Management commands:"
    echo "   Status:   docker-compose -f $COMPOSE_FILE ps"
    echo "   Logs:     docker-compose -f $COMPOSE_FILE logs -f"
    echo "   Stop:     docker-compose -f $COMPOSE_FILE down"
    echo "   Restart:  docker-compose -f $COMPOSE_FILE restart"
    echo ""
    echo "📂 Data is persisted in Docker volumes:"
    echo "   Lists:    mail_rulez_lists"
    echo "   Data:     mail_rulez_data"
    echo "   Logs:     mail_rulez_logs"
    echo "   Backups:  mail_rulez_backups"
    
else
    echo "❌ Failed to start Mail-Rulez. Checking logs..."
    docker-compose -f "$COMPOSE_FILE" logs
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Check if port ${PORT} is already in use"
    echo "   2. Verify Docker has enough resources allocated"
    echo "   3. Check the logs above for specific error messages"
    exit 1
fi