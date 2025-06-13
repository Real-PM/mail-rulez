#!/bin/bash
# Mail-Rulez Test Runner with Host Networking
# Workaround script for systems with Docker bridge network issues

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
DEFAULT_TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
IMAGE_NAME="mail-rulez:test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Help function
show_help() {
    cat << EOF
Mail-Rulez Test Runner with Host Networking

USAGE:
    $0 [OPTIONS] [TEST_PATTERN]

OPTIONS:
    -h, --help              Show this help message
    -c, --coverage          Run tests with coverage report
    -o, --output DIR        Test results output directory (default: ./test-results)
    -v, --verbose           Verbose output
    -q, --quiet             Quiet mode (minimal output)
    --rebuild               Force rebuild of test image
    --interactive           Run interactive shell in test container

EXAMPLES:
    # Run all tests with coverage
    $0 --coverage

    # Run specific test file
    $0 tests/test_config.py

    # Interactive debugging
    $0 --interactive

EOF
}

# Parse command line arguments
COVERAGE=false
VERBOSE=false
QUIET=false
REBUILD=false
INTERACTIVE=false
OUTPUT_DIR="$DEFAULT_TEST_RESULTS_DIR"
TEST_PATTERN="tests/"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TEST_PATTERN="$1"
            shift
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"
log_info "Test results will be saved to: $OUTPUT_DIR"

# Build image if needed
if [ "$REBUILD" = "true" ]; then
    log_info "Rebuilding test image..."
    if docker build --network=host -f "$SCRIPT_DIR/Dockerfile.test" -t "$IMAGE_NAME" "$PROJECT_ROOT"; then
        log_info "Test image rebuilt successfully"
    else
        log_error "Failed to rebuild test image"
        exit 1
    fi
elif ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_info "Building test image..."
    if docker build --network=host -f "$SCRIPT_DIR/Dockerfile.test" -t "$IMAGE_NAME" "$PROJECT_ROOT"; then
        log_info "Test image built successfully"
    else
        log_error "Failed to build test image"
        exit 1
    fi
fi

# Construct test command
if [ "$INTERACTIVE" = "true" ]; then
    log_info "Starting interactive test session..."
    docker run --rm -it --network=host \
        -v "$OUTPUT_DIR:/app/test-results" \
        -e MAIL_RULEZ_LOG_LEVEL=DEBUG \
        -e MAIL_RULEZ_SKIP_NETWORK_CHECK=true \
        -e MAIL_RULEZ_STRICT_VALIDATION=false \
        "$IMAGE_NAME" \
        bash
else
    # Build pytest command
    PYTEST_CMD="python -m pytest"
    
    if [ "$VERBOSE" = "true" ]; then
        PYTEST_CMD="$PYTEST_CMD -v"
    elif [ "$QUIET" = "true" ]; then
        PYTEST_CMD="$PYTEST_CMD -q"
    fi
    
    if [ "$COVERAGE" = "true" ]; then
        PYTEST_CMD="$PYTEST_CMD --cov=. --cov-report=html:test-results/htmlcov --cov-report=xml:test-results/coverage.xml --cov-report=term-missing"
    fi
    
    PYTEST_CMD="$PYTEST_CMD --html=test-results/report.html --self-contained-html $TEST_PATTERN"
    
    log_info "Running tests..."
    log_info "Command: $PYTEST_CMD"
    
    if docker run --rm --network=host \
        -v "$OUTPUT_DIR:/app/test-results" \
        -e MAIL_RULEZ_LOG_LEVEL=DEBUG \
        -e MAIL_RULEZ_SKIP_NETWORK_CHECK=true \
        -e MAIL_RULEZ_STRICT_VALIDATION=false \
        "$IMAGE_NAME" \
        bash -c "$PYTEST_CMD"; then
        
        log_info "Tests completed successfully!"
        
        # Show results summary
        if [ -f "$OUTPUT_DIR/report.html" ]; then
            log_info "HTML report available at: $OUTPUT_DIR/report.html"
        fi
        
        if [ -f "$OUTPUT_DIR/coverage.xml" ]; then
            log_info "Coverage report available at: $OUTPUT_DIR/htmlcov/index.html"
        fi
        
        exit 0
    else
        log_error "Tests failed!"
        exit 1
    fi
fi