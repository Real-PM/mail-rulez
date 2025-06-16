#!/bin/bash
# Mail-Rulez Secure Deployment Script
# For Ubuntu servers with standard Docker networking

set -e

echo "🚀 Mail-Rulez Secure Deployment"
echo "================================"

# Check if docker and docker-compose are available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p data lists logs backups config ssl

# Copy environment template if .env doesn't exist
if [ ! -f ".env" ]; then
    echo "📋 Creating .env from template..."
    cp .env.secure .env
    echo "⚠️  IMPORTANT: Edit .env file to set your FLASK_SECRET_KEY and MASTER_KEY"
    echo "   Generate MASTER_KEY with: openssl rand -base64 32"
    echo "   Generate FLASK_SECRET_KEY with: openssl rand -hex 32"
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.secure.yml down 2>/dev/null || true

# Build and start the application
echo "🔨 Building Mail-Rulez container..."
docker-compose -f docker-compose.secure.yml build

echo "🚀 Starting Mail-Rulez..."
docker-compose -f docker-compose.secure.yml up -d

# Wait for health check
echo "🏥 Waiting for health check..."
sleep 10

# Check if container is running
if docker-compose -f docker-compose.secure.yml ps | grep -q "Up"; then
    PORT=$(grep "^PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "5001")
    echo "✅ Mail-Rulez is running!"
    echo "🌐 Access at: http://localhost:${PORT}"
    echo "📊 Check status: docker-compose -f docker-compose.secure.yml ps"
    echo "📋 View logs: docker-compose -f docker-compose.secure.yml logs -f"
else
    echo "❌ Failed to start Mail-Rulez. Check logs:"
    docker-compose -f docker-compose.secure.yml logs
    exit 1
fi