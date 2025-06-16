#!/bin/bash
# Mail-Rulez Containerized Test Runner
# Provides comprehensive testing capabilities using Docker containers

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.test.yml"

# Default configuration
DEFAULT_TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
DEFAULT_TEST_PATTERN="tests/"
DEFAULT_PARALLEL_WORKERS="auto"

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
Mail-Rulez Containerized Test Runner

USAGE:
    $0 [OPTIONS] [TEST_PATTERN]

OPTIONS:
    -h, --help              Show this help message
    -c, --coverage          Run tests with coverage report
    -p, --parallel          Run tests in parallel (default: auto)
    -w, --workers NUM       Number of parallel workers (default: auto)
    -o, --output DIR        Test results output directory (default: ./test-results)
    -v, --verbose           Verbose output
    -d, --debug             Enable debug output
    -q, --quiet             Quiet mode (minimal output)
    --clean                 Clean up containers and volumes after tests
    --no-build              Skip building test image
    --rebuild               Force rebuild of test image
    --interactive           Run tests interactively (for debugging)
    --lint-only             Run only linting checks
    --unit-only             Run only unit tests
    --integration-only      Run only integration tests
    --smoke-test            Run smoke tests only
    --format FORMAT         Test report format (html|xml|json|term)

TEST_PATTERN:
    Specific test pattern to run (default: tests/)
    Examples:
        tests/test_config.py           # Single file
        tests/test_config.py::TestClass # Specific test class
        tests/ -k "test_security"      # Tests matching pattern

ENVIRONMENT VARIABLES:
    TEST_RESULTS_DIR        Override default test results directory
    PARALLEL_WORKERS        Number of parallel workers
    DEBUG                   Enable debug output (true/false)
    DOCKER_BUILDKIT         Enable Docker BuildKit (default: 1)

EXAMPLES:
    # Run all tests with coverage
    $0 --coverage

    # Run specific test file in parallel
    $0 --parallel tests/test_config.py

    # Run tests with custom output directory
    $0 --output /tmp/test-results tests/

    # Run smoke tests only
    $0 --smoke-test

    # Interactive debugging session
    $0 --interactive

    # Clean run with rebuild
    $0 --clean --rebuild --coverage

EOF
}

# Parse command line arguments
COVERAGE=false
PARALLEL=false
WORKERS="${PARALLEL_WORKERS:-auto}"
OUTPUT_DIR="${TEST_RESULTS_DIR:-$DEFAULT_TEST_RESULTS_DIR}"
VERBOSE=false
QUIET=false
CLEAN=false
NO_BUILD=false
REBUILD=false
INTERACTIVE=false
LINT_ONLY=false
UNIT_ONLY=false
INTEGRATION_ONLY=false
SMOKE_TEST=false
FORMAT="html"
TEST_PATTERN="$DEFAULT_TEST_PATTERN"

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
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -w|--workers)
            WORKERS="$2"
            PARALLEL=true
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
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
        --lint-only)
            LINT_ONLY=true
            shift
            ;;
        --unit-only)
            UNIT_ONLY=true
            shift
            ;;
        --integration-only)
            INTEGRATION_ONLY=true
            shift
            ;;
        --smoke-test)
            SMOKE_TEST=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
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

# Validate environment
log_info "Validating environment..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
    log_error "Docker Compose is not available"
    exit 1
fi

# Use docker compose if available, fallback to docker-compose
COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null; then
    COMPOSE_CMD="docker-compose"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
log_info "Test results will be saved to: $OUTPUT_DIR"

# Set environment variables for Docker Compose
export TEST_RESULTS_DIR="$OUTPUT_DIR"
export SOURCE_DIR="$PROJECT_ROOT"
export DOCKER_BUILDKIT=1

# Cleanup function
cleanup() {
    if [ "$CLEAN" = "true" ]; then
        log_info "Cleaning up containers and volumes..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true
        docker system prune -f 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Build test image if needed
if [ "$NO_BUILD" != "true" ]; then
    if [ "$REBUILD" = "true" ]; then
        log_info "Rebuilding test image..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache
    else
        log_info "Building test image..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" build
    fi
fi

# Construct test command
TEST_CMD="python -m pytest"

# Add verbosity options
if [ "$VERBOSE" = "true" ]; then
    TEST_CMD="$TEST_CMD -v"
elif [ "$QUIET" = "true" ]; then
    TEST_CMD="$TEST_CMD -q"
fi

# Add coverage options
if [ "$COVERAGE" = "true" ]; then
    TEST_CMD="$TEST_CMD --cov=. --cov-report=html:test-results/htmlcov --cov-report=xml:test-results/coverage.xml --cov-report=term-missing"
fi

# Add parallel options
if [ "$PARALLEL" = "true" ]; then
    TEST_CMD="$TEST_CMD -n $WORKERS"
fi

# Add output format options
case "$FORMAT" in
    html)
        TEST_CMD="$TEST_CMD --html=test-results/report.html --self-contained-html"
        ;;
    xml)
        TEST_CMD="$TEST_CMD --junitxml=test-results/junit.xml"
        ;;
    json)
        TEST_CMD="$TEST_CMD --json-report --json-report-file=test-results/report.json"
        ;;
    term)
        # Default terminal output
        ;;
    *)
        log_warn "Unknown format: $FORMAT, using default terminal output"
        ;;
esac

# Add test selection options
if [ "$LINT_ONLY" = "true" ]; then
    TEST_CMD="python -m flake8 . && python -m black --check ."
elif [ "$UNIT_ONLY" = "true" ]; then
    TEST_CMD="$TEST_CMD -m 'not integration'"
elif [ "$INTEGRATION_ONLY" = "true" ]; then
    TEST_CMD="$TEST_CMD -m 'integration'"
elif [ "$SMOKE_TEST" = "true" ]; then
    TEST_CMD="$TEST_CMD -m 'smoke'"
fi

# Add test pattern
TEST_CMD="$TEST_CMD $TEST_PATTERN"

log_debug "Test command: $TEST_CMD"

# Run tests
if [ "$INTERACTIVE" = "true" ]; then
    log_info "Starting interactive test session..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" run --rm mail-rulez-test bash
else
    log_info "Running tests..."
    log_info "Command: $TEST_CMD"
    
    if $COMPOSE_CMD -f "$COMPOSE_FILE" run --rm mail-rulez-test bash -c "$TEST_CMD"; then
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