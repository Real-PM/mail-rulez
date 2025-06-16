@echo off
REM Mail-Rulez Universal Deployment Script for Windows
REM Compatible with Windows Command Prompt and PowerShell

echo 🚀 Mail-Rulez Universal Deployment
echo ===================================
echo 🖥️  Detected OS: Windows

REM Check if docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not installed or not in PATH.
    echo    Please install Docker Desktop for Windows
    echo    Visit: https://docs.docker.com/desktop/windows/
    pause
    exit /b 1
)

REM Check if docker-compose is available
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not installed or not in PATH.
    echo    Please install Docker Desktop or docker-compose
    pause
    exit /b 1
)

REM Check Docker daemon is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker daemon is not running.
    echo    Please start Docker Desktop
    pause
    exit /b 1
)

echo ✅ Docker and Docker Compose are available

REM Create necessary directories
echo 📁 Creating directories...
if not exist "data" mkdir data
if not exist "lists" mkdir lists
if not exist "logs" mkdir logs
if not exist "backups" mkdir backups
if not exist "config" mkdir config

REM Handle environment file setup
set ENV_FILE=.env
set ENV_TEMPLATE=.env.secure

if not exist "%ENV_FILE%" (
    if exist "%ENV_TEMPLATE%" (
        echo 📋 Creating %ENV_FILE% from template...
        copy "%ENV_TEMPLATE%" "%ENV_FILE%" >nul
    ) else (
        echo 📋 Creating basic %ENV_FILE%...
        (
            echo # Mail-Rulez Configuration
            echo PORT=5001
            echo FLASK_SECRET_KEY=change-this-to-a-long-random-string-in-production
            echo MASTER_KEY=generate-this-with-openssl-rand-base64-32
            echo LOG_LEVEL=INFO
            echo LOG_RETENTION_DAYS=30
            echo STRICT_VALIDATION=true
            echo SKIP_NETWORK_CHECK=false
        ) > "%ENV_FILE%"
    )
    echo ⚠️  IMPORTANT: Edit %ENV_FILE% and set secure keys!
) else (
    echo ✅ Environment file %ENV_FILE% already exists
)

REM Use universal docker-compose file
set COMPOSE_FILE=docker-compose.universal.yml
if not exist "%COMPOSE_FILE%" (
    echo ❌ %COMPOSE_FILE% not found. Using docker-compose.yml as fallback.
    set COMPOSE_FILE=docker-compose.yml
)

REM Stop any existing containers
echo 🛑 Stopping existing containers...
docker-compose -f "%COMPOSE_FILE%" down >nul 2>&1

REM Build and start the application
echo 🔨 Building Mail-Rulez container...
docker-compose -f "%COMPOSE_FILE%" build

echo 🚀 Starting Mail-Rulez...
docker-compose -f "%COMPOSE_FILE%" up -d

REM Wait for container to start
echo ⏳ Waiting for container to start...
timeout /t 10 /nobreak >nul

REM Check if container is running
docker-compose -f "%COMPOSE_FILE%" ps | findstr "mail-rulez" >nul
if errorlevel 1 (
    echo ❌ Failed to start Mail-Rulez. Checking logs...
    docker-compose -f "%COMPOSE_FILE%" logs
    echo.
    echo 🔧 Troubleshooting:
    echo    1. Check if port 5001 is already in use
    echo    2. Verify Docker Desktop has enough resources allocated
    echo    3. Check the logs above for specific error messages
    pause
    exit /b 1
) else (
    echo ✅ Mail-Rulez is running!
    echo.
    echo 🌐 Access URLs:
    echo    Local:    http://localhost:5001
    echo    Network:  http://^<your-ip^>:5001
    echo.
    echo 📊 Management commands:
    echo    Status:   docker-compose -f %COMPOSE_FILE% ps
    echo    Logs:     docker-compose -f %COMPOSE_FILE% logs -f
    echo    Stop:     docker-compose -f %COMPOSE_FILE% down
    echo    Restart:  docker-compose -f %COMPOSE_FILE% restart
    echo.
    echo 📂 Data is persisted in Docker volumes
    echo.
    echo Press any key to exit...
    pause >nul
)