# Mail-Rulez Docker Testing Guide

This comprehensive guide covers all aspects of testing Mail-Rulez in containerized environments, from unit tests to extended production-like testing.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Test Types](#test-types)
- [Quick Start](#quick-start)
- [Unit and Integration Testing](#unit-and-integration-testing)
- [Extended Testing](#extended-testing)
- [Sandbox Testing](#sandbox-testing)
- [Production Testing](#production-testing)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

## Overview

Mail-Rulez includes a comprehensive Docker-based testing infrastructure that provides:

- **Isolated test environment** with consistent dependencies
- **Automated test execution** with coverage reporting
- **Extended testing** for startup-to-maintenance mode transitions
- **Production-like testing** scenarios
- **Performance monitoring** and metrics collection
- **Comprehensive reporting** with HTML and XML outputs

### Test Architecture

```
mail_rules_rpm/
├── docker/
│   ├── Dockerfile.test           # Test-specific container
│   ├── docker-compose.test.yml   # Test environment
│   ├── run-tests.sh             # Full-featured test runner
│   ├── run-tests-host-network.sh # Network issue workaround
│   └── extended-test.sh          # Long-running tests
├── tests/                        # Test suite (109 tests)
└── test-results/                 # Generated reports
```

## Prerequisites

### Required Software
- Docker Engine 20.10+ with BuildKit support
- Docker Compose 2.0+ (or docker-compose 1.29+)
- 512MB+ available memory
- 1GB+ available disk space

### System Requirements
- Linux, macOS, or Windows with WSL2
- Network connectivity (for building images)
- Sufficient permissions to run Docker commands

### Verification
```bash
# Verify Docker installation
docker --version
docker compose version  # or docker-compose --version

# Test Docker functionality
docker run hello-world
```

## Test Types

### 1. Unit Tests
- **Count:** 109 tests
- **Coverage:** 57% overall
- **Duration:** ~1-2 seconds
- **Scope:** Individual functions and classes

### 2. Integration Tests
- **Components:** Web app, services, email processing
- **Duration:** ~5-10 seconds
- **Scope:** Component interactions

### 3. Extended Tests
- **Duration:** 15+ minutes (configurable)
- **Scope:** Startup-to-maintenance mode transitions
- **Monitoring:** Real-time health checks and metrics

### 4. Production Tests
- **Duration:** Hours to days
- **Scope:** Full application lifecycle
- **Features:** Continuous monitoring, automatic reporting

## Quick Start

### 1. Run All Tests
```bash
# Navigate to project directory
cd /path/to/mail_rules_rpm

# Run all tests with coverage
./docker/run-tests-host-network.sh --coverage

# Expected output: "109 passed"
```

### 2. Run Specific Tests
```bash
# Run single test file
./docker/run-tests-host-network.sh tests/test_config.py

# Run specific test
./docker/run-tests-host-network.sh tests/test_config.py::TestConfig::test_config_creation

# Run with pattern matching
./docker/run-tests-host-network.sh tests/ -k "security"
```

### 3. Interactive Debugging
```bash
# Open interactive shell in test container
./docker/run-tests-host-network.sh --interactive

# Inside container, run tests manually
python -m pytest tests/test_config.py -v
```

## Unit and Integration Testing

### Test Environment Setup

The test environment uses a dedicated Docker image with:
- Python 3.10 runtime
- All application dependencies
- Testing tools (pytest, coverage, etc.)
- Isolated filesystem with test-specific directories

### Test Execution Options

#### Basic Test Execution
```bash
# All tests with standard output
./docker/run-tests-host-network.sh

# Verbose output
./docker/run-tests-host-network.sh --verbose

# Quiet mode (minimal output)
./docker/run-tests-host-network.sh --quiet
```

#### Coverage Reporting
```bash
# Generate coverage reports
./docker/run-tests-host-network.sh --coverage

# Results available in:
# - test-results/htmlcov/index.html (HTML report)
# - test-results/coverage.xml (XML for CI/CD)
# - Terminal output (summary)
```

#### Advanced Options
```bash
# Force rebuild test image
./docker/run-tests-host-network.sh --rebuild

# Custom output directory
./docker/run-tests-host-network.sh --output /tmp/my-test-results

# Parallel execution (if supported)
./docker/run-tests-host-network.sh --parallel
```

### Test Categories

#### Configuration Tests (`tests/test_config.py`)
- Account configuration management
- Environment variable handling
- Path configuration
- List file management

```bash
# Run configuration tests
./docker/run-tests-host-network.sh tests/test_config.py
```

#### Security Tests (`tests/test_security.py`)
- Password encryption/decryption
- Session management
- User authentication
- Account lockout mechanisms

```bash
# Run security tests
./docker/run-tests-host-network.sh tests/test_security.py
```

#### Email Processing Tests (`tests/test_process_inbox.py`)
- Email categorization logic
- List-based filtering
- Folder movement operations
- Maintenance vs. startup modes

```bash
# Run email processing tests
./docker/run-tests-host-network.sh tests/test_process_inbox.py
```

#### Service Tests (`tests/test_services.py`)
- Email processor service lifecycle
- Scheduler management
- Mode transitions
- Error handling

```bash
# Run service tests
./docker/run-tests-host-network.sh tests/test_services.py
```

#### Web Application Tests (`tests/test_web_app.py`)
- Flask app creation
- Route registration
- Authentication flows
- Template rendering

```bash
# Run web app tests
./docker/run-tests-host-network.sh tests/test_web_app.py
```

### Test Results Interpretation

#### Success Indicators
```
======================== 109 passed in X.XXs =========================
✅ Tests completed successfully!
```

#### Failure Analysis
```
======================== FAILURES ===================================
______ TestName.test_method ______

# Detailed error information follows
# Check the specific assertion that failed
# Review stack trace for root cause
```

#### Coverage Metrics
- **High Coverage (>80%):** config.py, security.py, test files
- **Medium Coverage (50-80%):** process_inbox.py, logging_config.py
- **Low Coverage (<50%):** web routes, services (due to mocking complexity)

### Performance Benchmarks

| Test Category | Expected Duration | Pass Criteria |
|---------------|------------------|---------------|
| Unit Tests | < 1 second | All assertions pass |
| Integration Tests | 1-5 seconds | Service interactions work |
| Full Suite | < 10 seconds | 109/109 tests pass |

## Extended Testing

### Overview

Extended testing validates the application's behavior over longer periods, specifically testing the critical startup-to-maintenance mode transition.

### Extended Test Features

- **Configurable Duration:** Set custom time periods for each phase
- **Real-time Monitoring:** Health checks every 30 seconds
- **Automatic Transition:** Triggers mode switches automatically
- **Metrics Collection:** CPU, memory, disk usage tracking
- **Comprehensive Reporting:** Detailed logs and final report

### Extended Test Execution

#### Quick Extended Test (5 minutes total)
```bash
# Short test for development
./docker/extended-test.sh --startup-duration 120 --maint-duration 180
```

#### Standard Extended Test (15 minutes total)
```bash
# Default configuration
./docker/extended-test.sh

# Equivalent to:
# --startup-duration 300 (5 minutes)
# --maint-duration 600 (10 minutes)
# --transition-time 30 (30 seconds)
```

#### Production Extended Test (1 hour total)
```bash
# Production-like duration
./docker/extended-test.sh \
  --startup-duration 1800 \
  --maint-duration 2400 \
  --transition-time 60
```

#### Continuous Testing
```bash
# Run continuously until manually stopped
./docker/extended-test.sh --continuous --debug

# Stop with Ctrl+C
```

### Extended Test Phases

#### Phase 1: Startup Mode Testing
- **Duration:** 5 minutes (default)
- **Monitoring:** Every 30 seconds
- **Validations:**
  - Container health status
  - Application startup completion
  - Service initialization
  - Resource usage baselines

#### Phase 2: Mode Transition
- **Duration:** 30 seconds (default)
- **Monitoring:** Every 5 seconds
- **Validations:**
  - Transition trigger successful
  - Service state changes correctly
  - No errors during transition
  - Resource usage stability

#### Phase 3: Maintenance Mode Testing
- **Duration:** 10 minutes (default)
- **Monitoring:** Every 60 seconds
- **Validations:**
  - Stable maintenance mode operation
  - Resource usage patterns
  - Long-term stability
  - Error-free operation

### Extended Test Configuration

#### Environment Variables
```bash
# Custom test configuration
export EXTENDED_TEST_STARTUP_DURATION=600
export EXTENDED_TEST_MAINT_DURATION=1200
export EXTENDED_TEST_DEBUG=true

./docker/extended-test.sh
```

#### Test Data Setup
```bash
# Create custom test configuration
mkdir -p ./custom-test-config

# Extended test will use this configuration
./docker/extended-test.sh --output ./custom-test-results
```

### Extended Test Output

#### Directory Structure
```
extended-test-results-YYYYMMDD_HHMMSS/
├── extended-test.log           # Complete execution log
├── startup_metrics.log         # Startup phase metrics
├── maintenance_metrics.log     # Maintenance phase metrics
├── final_metrics.log          # Final system state
├── test_report.md             # Summary report
├── config/                    # Test configuration
├── logs/                      # Application logs
├── data/                      # Application data
└── lists/                     # Email lists
```

#### Test Report Example
```markdown
# Mail-Rulez Extended Test Report

**Test Date:** 2024-06-13 14:30:00
**Total Duration:** 930s
**Startup Duration:** 300s
**Transition Duration:** 28s
**Maintenance Duration:** 600s

## Test Results

✅ **PASSED** - Application started successfully in startup mode
✅ **PASSED** - Application operated correctly during startup phase
✅ **PASSED** - Mode transition completed within expected time
✅ **PASSED** - Application operated correctly during maintenance phase
✅ **PASSED** - No errors or crashes detected during extended testing

**Status: PASSED** ✅
```

### Extended Test Monitoring

#### Real-time Monitoring
```bash
# Monitor test progress in separate terminal
tail -f extended-test-results-*/extended-test.log

# Monitor container resources
docker stats mail-rulez-extended-test
```

#### Health Check Validation
```bash
# Manual health check
docker exec mail-rulez-extended-test python -c "
import requests
response = requests.get('http://localhost:5001/health')
print(f'Health: {response.status_code}')
"
```

## Sandbox Testing

### Overview

Sandbox testing provides a complete, containerized Mail-Rulez instance for manual testing, UAT (User Acceptance Testing), and development sandboxing. This is perfect for interactive testing, demonstrations, and exploring the application's functionality.

The sandbox runner (`docker/run-sandbox.sh`) creates a fully functional Mail-Rulez environment with:
- **Web interface** accessible via browser
- **Sample data** for immediate testing
- **Isolated environment** that doesn't affect your host system
- **Easy management** with simple commands
- **Flexible configuration** for different testing scenarios

### Quick Start - Sandbox Testing

#### 1. Start the Sandbox
```bash
# Start with default settings (development mode on port 5001)
./docker/run-sandbox.sh start

# Access at: http://localhost:5001
```

#### 2. Alternative Startup Options
```bash
# Start on custom port
./docker/run-sandbox.sh start --port 8080

# Start in production mode
./docker/run-sandbox.sh start --type production

# Start in foreground with live logs
./docker/run-sandbox.sh start --foreground

# Start with debugging enabled
./docker/run-sandbox.sh start --debug --foreground
```

### Sandbox Management Commands

#### Container Management
```bash
# View real-time logs
./docker/run-sandbox.sh logs

# Check status and health
./docker/run-sandbox.sh status

# Open interactive shell
./docker/run-sandbox.sh shell

# Restart container
./docker/run-sandbox.sh restart

# Stop container
./docker/run-sandbox.sh stop

# Clean everything (container + data)
./docker/run-sandbox.sh clean
```

#### Development Workflow
```bash
# Force rebuild and restart (after code changes)
./docker/run-sandbox.sh rebuild

# Clean restart (fresh container, keep data)
./docker/run-sandbox.sh restart --clean-start

# Debug mode with all logging
./docker/run-sandbox.sh start --debug --foreground --type development
```

### Sandbox Environment Structure

When you start the sandbox, it automatically creates a complete testing environment:

```
sandbox/
├── data/         # Application data and runtime files
├── lists/        # Email lists with sample data
│   ├── white.txt    # Trusted senders (auto-processed)
│   ├── black.txt    # Blocked senders (sent to junk)
│   └── vendor.txt   # Commercial emails (sent to approved ads)
├── logs/         # Application logs and debugging output
├── config/       # Configuration files
│   └── accounts.json  # Email account settings (sample)
└── backups/      # Backup storage directory
```

#### Sample List Contents

The sandbox automatically creates sample email lists for testing:

**white.txt** (Trusted senders):
```
friend@example.com
newsletter@trusted-company.com
support@known-service.com
```

**black.txt** (Blocked senders):
```
spam@badsite.com
noreply@suspicious-domain.com
```

**vendor.txt** (Commercial emails):
```
marketing@retailer.com
promotions@store.com
deals@shopping-site.com
```

### Access Points

Once the sandbox is running, you can access:

- **🌐 Main Web Interface:** `http://localhost:5001`
  - Login/setup wizard
  - Email account configuration
  - Rules management
  - List management
  - Dashboard and monitoring

- **❤️ Health Check:** `http://localhost:5001/health`
  - Container health status
  - Service availability check

- **📊 API Status:** `http://localhost:5001/api/status`
  - Service status information
  - Performance metrics

### UAT and Testing Scenarios

#### Scenario 1: Basic Web Interface Testing
```bash
# Start sandbox
./docker/run-sandbox.sh start

# Open browser to http://localhost:5001
# Test the following:
# - Initial setup wizard
# - User login/authentication
# - Navigation between pages
# - Configuration forms
# - List management interface
```

**Test Checklist:**
- [ ] Setup wizard completes successfully
- [ ] Login authentication works
- [ ] All navigation links functional
- [ ] Forms submit without errors
- [ ] Data persists between sessions

#### Scenario 2: Email Processing Testing
```bash
# Start with mock email server
./docker/run-sandbox.sh start --mock-email

# Configure test accounts through web interface
# Verify email categorization logic
```

**Test Areas:**
- [ ] Email account configuration
- [ ] List management (add/remove entries)
- [ ] Email categorization rules
- [ ] Folder organization
- [ ] Processing mode transitions

#### Scenario 3: Performance and Load Testing
```bash
# Start production mode
./docker/run-sandbox.sh start --type production

# Monitor performance
./docker/run-sandbox.sh status

# Run load tests against http://localhost:5001
```

**Performance Monitoring:**
```bash
# Real-time resource monitoring
watch './docker/run-sandbox.sh status'

# Continuous log monitoring
./docker/run-sandbox.sh logs | grep -E "(ERROR|WARN|Processing)"

# Container resource usage
docker stats mail-rulez-sandbox --no-stream
```

#### Scenario 4: Configuration Testing
```bash
# Start sandbox
./docker/run-sandbox.sh start

# Edit configuration files
vim sandbox/config/accounts.json
vim sandbox/lists/white.txt

# Apply changes
./docker/run-sandbox.sh restart

# Verify configuration changes take effect
```

**Configuration Test Cases:**
- [ ] Account settings modification
- [ ] Email list updates
- [ ] Folder mapping changes
- [ ] Retention policy adjustments
- [ ] Security settings

#### Scenario 5: Extended Operation Testing
```bash
# Start for long-term testing
./docker/run-sandbox.sh start --type production

# Monitor over time
./docker/run-sandbox.sh logs | tee long-term-test.log

# Check status periodically
watch -n 300 './docker/run-sandbox.sh status'  # Every 5 minutes
```

**Long-term Testing Focus:**
- [ ] Memory usage stability
- [ ] Log rotation functionality
- [ ] Session management
- [ ] Database persistence
- [ ] Error recovery

#### Scenario 6: Startup to Maintenance Mode Transition
```bash
# Start sandbox in startup mode
./docker/run-sandbox.sh start --debug --foreground

# In another terminal, monitor the transition
./docker/run-sandbox.sh shell
# Inside container: monitor logs, check service status

# Or run extended test alongside sandbox
./docker/extended-test.sh --startup-duration 300 --maint-duration 600
```

### Advanced Sandbox Usage

#### Custom Data Directory
```bash
# Use custom sandbox location
./docker/run-sandbox.sh start --data-dir /path/to/my/test-data

# Useful for:
# - Persistent test environments
# - Shared testing data
# - Backup/restore scenarios
```

#### Multiple Sandbox Instances
```bash
# Run multiple sandboxes for different test scenarios
./docker/run-sandbox.sh start --name mail-rulez-uat --port 5002
./docker/run-sandbox.sh start --name mail-rulez-dev --port 5003
./docker/run-sandbox.sh start --name mail-rulez-staging --port 5004

# Access different environments:
# UAT: http://localhost:5002
# DEV: http://localhost:5003
# Staging: http://localhost:5004
```

#### Production-like Sandbox Setup
```bash
# Production mode with realistic configuration
./docker/run-sandbox.sh start \
  --type production \
  --port 80 \
  --data-dir /var/mail-rulez-data \
  --name mail-rulez-production-test

# For testing:
# - Production Docker image
# - Realistic data volumes
# - Production-like networking
# - Resource constraints
```

### Sandbox Debugging and Troubleshooting

#### Debug Mode
```bash
# Start with full debugging
./docker/run-sandbox.sh start --debug --foreground

# Features:
# - Verbose logging output
# - Debug-level application logs
# - Real-time log streaming
# - Detailed error information
```

#### Interactive Debugging
```bash
# Open shell in running sandbox
./docker/run-sandbox.sh shell

# Inside container - useful commands:
ps aux                           # Check running processes
tail -f /app/logs/*.log         # Monitor logs
python -c "import config; print(config.get_config().base_dir)"  # Check config
curl localhost:5001/health      # Test health endpoint
```

#### Log Analysis
```bash
# Application logs
./docker/run-sandbox.sh logs | grep ERROR

# Container logs with timestamps
docker logs mail-rulez-sandbox --timestamps

# Specific log files
docker exec mail-rulez-sandbox cat /app/logs/mail_rulez.log
docker exec mail-rulez-sandbox cat /app/logs/email_processing.log
```

### Integration with Extended Testing

The sandbox can be used alongside extended testing for comprehensive validation:

```bash
# Terminal 1: Start sandbox for manual monitoring
./docker/run-sandbox.sh start --debug --foreground

# Terminal 2: Run extended automated tests
./docker/extended-test.sh --startup-duration 300 --maint-duration 600

# Terminal 3: Manual testing and validation
# - Open http://localhost:5001 in browser
# - Monitor web interface during transitions
# - Verify data consistency
# - Test user interactions
```

### Sandbox Best Practices

#### Development Workflow
1. **Start Fresh:** Use `--clean-start` for clean testing environment
2. **Debug Mode:** Use `--debug --foreground` during development
3. **Quick Rebuild:** Use `rebuild` command after code changes
4. **Log Monitoring:** Keep logs open in separate terminal

#### UAT Workflow
1. **Production Mode:** Use `--type production` for realistic testing
2. **Persistent Data:** Use custom `--data-dir` for test continuity
3. **Multiple Instances:** Test different scenarios simultaneously
4. **Documentation:** Record test cases and results

#### Continuous Testing
1. **Automated Startup:** Script sandbox startup for CI/CD
2. **Health Monitoring:** Regular health checks during testing
3. **Resource Monitoring:** Track performance over time
4. **Cleanup:** Regular cleanup of old sandbox instances

### Sandbox Help and Options

```bash
# Full help and options
./docker/run-sandbox.sh --help

# Key options:
-p, --port PORT         Host port to bind (default: 5001)
-t, --type TYPE         Image type: development|production
-n, --name NAME         Container name
-f, --foreground        Run in foreground with logs
--data-dir DIR          Custom data directory
--rebuild               Force rebuild image
--clean-start           Clean existing container
--debug                 Enable debug output
--mock-email            Use mock email server
```

The sandbox testing environment provides a complete, isolated Mail-Rulez instance that's perfect for manual testing, UAT scenarios, demonstrations, and interactive development. It combines the reliability of containerization with the flexibility needed for comprehensive testing.

## Production Testing

### Production-like Environment

For production testing, use the production Docker image with realistic configurations:

```bash
# Build production image
docker build -f docker/Dockerfile --target production -t mail-rulez:prod .

# Run with production configuration
docker run -d \
  --name mail-rulez-prod-test \
  -p 5001:5001 \
  -v $(pwd)/prod-data:/app/data \
  -v $(pwd)/prod-logs:/app/logs \
  -e FLASK_ENV=production \
  -e MAIL_RULEZ_LOG_LEVEL=INFO \
  mail-rulez:prod
```

### Production Test Scenarios

#### Load Testing
```bash
# Use Apache Bench for basic load testing
ab -n 1000 -c 10 http://localhost:5001/

# Use curl for API testing
for i in {1..100}; do
  curl -s http://localhost:5001/health > /dev/null
  echo "Request $i completed"
done
```

#### Stress Testing
```bash
# Monitor resource usage under load
docker stats mail-rulez-prod-test

# Check for memory leaks
./docker/extended-test.sh --continuous --debug
```

#### Failover Testing
```bash
# Test container restart
docker restart mail-rulez-prod-test

# Test graceful shutdown
docker stop mail-rulez-prod-test
```

### Production Monitoring

#### Log Analysis
```bash
# Check for errors in production logs
docker logs mail-rulez-prod-test | grep ERROR

# Monitor real-time logs
docker logs -f mail-rulez-prod-test
```

#### Performance Metrics
```bash
# Container resource usage
docker exec mail-rulez-prod-test cat /proc/meminfo
docker exec mail-rulez-prod-test df -h

# Application-specific metrics
curl http://localhost:5001/metrics  # If metrics endpoint exists
```

## Troubleshooting

### Common Issues

#### 1. Docker Network Issues
**Problem:** `failed to add the host <=> sandbox pair interfaces: operation not supported`

**Solution:** Use host networking workaround:
```bash
# Use the host-network test runner
./docker/run-tests-host-network.sh

# Or build with host networking
docker build --network=host -f docker/Dockerfile.test -t mail-rulez:test .
```

#### 2. Permission Errors
**Problem:** Container can't write to mounted volumes

**Solution:** Fix directory permissions:
```bash
# Create directories with correct permissions
mkdir -p test-results logs data lists
chmod 777 test-results logs data lists

# Or run container as current user
docker run --user $(id -u):$(id -g) ...
```

#### 3. Build Failures
**Problem:** Docker build fails due to network or dependency issues

**Solution:** Clear Docker cache and rebuild:
```bash
# Clear Docker build cache
docker builder prune -a

# Rebuild with no cache
./docker/run-tests-host-network.sh --rebuild
```

#### 4. Test Failures
**Problem:** Tests fail with environment-related issues

**Solution:** Check test isolation:
```bash
# Run single test in isolation
./docker/run-tests-host-network.sh tests/test_config.py::TestConfig::test_specific_test

# Check test dependencies
./docker/run-tests-host-network.sh --interactive
# Inside container: python -c "import sys; print(sys.path)"
```

#### 5. Extended Test Issues
**Problem:** Extended test fails to start or monitor correctly

**Solution:** Debug extended test execution:
```bash
# Run with debug output
./docker/extended-test.sh --debug --startup-duration 60

# Check container status manually
docker ps -a
docker logs mail-rulez-extended-test
```

### Debug Mode

#### Enable Debug Logging
```bash
# For unit tests
./docker/run-tests-host-network.sh --debug

# For extended tests
./docker/extended-test.sh --debug

# For production testing
docker run -e MAIL_RULEZ_LOG_LEVEL=DEBUG mail-rulez:prod
```

#### Interactive Debugging
```bash
# Open shell in test container
./docker/run-tests-host-network.sh --interactive

# Inside container - run tests step by step
python -m pytest tests/test_config.py::TestConfig::test_specific_test -v -s

# Check environment
env | grep MAIL_RULEZ
```

### Performance Issues

#### Slow Test Execution
```bash
# Run tests in parallel (if available)
./docker/run-tests-host-network.sh --parallel

# Profile test execution
python -m pytest tests/ --durations=10
```

#### Memory Issues
```bash
# Monitor memory usage
docker stats --no-stream

# Limit container memory
docker run --memory=512m mail-rulez:test
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Mail-Rulez Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker
      uses: docker/setup-buildx-action@v2
    
    - name: Build test image
      run: docker build --network=host -f docker/Dockerfile.test -t mail-rulez:test .
    
    - name: Run unit tests
      run: ./docker/run-tests-host-network.sh --coverage
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./test-results/coverage.xml
    
    - name: Run extended tests
      if: github.ref == 'refs/heads/main'
      run: ./docker/extended-test.sh --startup-duration 120 --maint-duration 180
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'docker build --network=host -f docker/Dockerfile.test -t mail-rulez:test .'
            }
        }
        
        stage('Test') {
            steps {
                sh './docker/run-tests-host-network.sh --coverage'
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'test-results/htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Extended Test') {
            when {
                branch 'main'
            }
            steps {
                sh './docker/extended-test.sh --startup-duration 300 --maint-duration 600'
            }
        }
    }
}
```

### GitLab CI Example

```yaml
stages:
  - build
  - test
  - extended-test

variables:
  DOCKER_BUILDKIT: 1

build:
  stage: build
  script:
    - docker build --network=host -f docker/Dockerfile.test -t mail-rulez:test .

unit-tests:
  stage: test
  script:
    - ./docker/run-tests-host-network.sh --coverage
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: test-results/coverage.xml
    paths:
      - test-results/

extended-tests:
  stage: extended-test
  script:
    - ./docker/extended-test.sh --startup-duration 180 --maint-duration 300
  only:
    - main
  artifacts:
    paths:
      - extended-test-results-*/
```

## Best Practices

### Development Workflow

1. **Before Code Changes:**
   ```bash
   # Ensure all tests pass
   ./docker/run-tests-host-network.sh
   ```

2. **After Code Changes:**
   ```bash
   # Run affected tests
   ./docker/run-tests-host-network.sh tests/test_modified_component.py
   
   # Run full suite before commit
   ./docker/run-tests-host-network.sh --coverage
   ```

3. **Before Release:**
   ```bash
   # Run extended tests
   ./docker/extended-test.sh
   
   # Run production-like tests
   ./docker/extended-test.sh --startup-duration 900 --maint-duration 1800
   ```

### Test Maintenance

#### Regular Tasks
- **Weekly:** Run extended tests on development branch
- **Monthly:** Update test dependencies and rebuild images
- **Release:** Run full test suite including production scenarios

#### Test Data Management
```bash
# Clean up old test results
find . -name "test-results-*" -mtime +7 -exec rm -rf {} \;
find . -name "extended-test-results-*" -mtime +30 -exec rm -rf {} \;

# Archive important test results
tar -czf test-results-$(date +%Y%m%d).tar.gz test-results/
```

### Performance Optimization

#### Container Optimization
```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Use layer caching
docker build --cache-from mail-rulez:test-cache .

# Parallel testing where possible
./docker/run-tests-host-network.sh --parallel
```

#### Resource Management
```bash
# Limit container resources
docker run --memory=512m --cpus=1.0 mail-rulez:test

# Monitor resource usage
docker stats --no-stream mail-rulez-test
```

This comprehensive testing guide ensures reliable, repeatable testing of Mail-Rulez in containerized environments, from quick unit tests to extended production-like scenarios.