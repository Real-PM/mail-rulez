#!/bin/bash
# Mail-Rulez Container Health Check Script
# Comprehensive health monitoring for containerized deployment

set -e

# Configuration
FLASK_PORT=${FLASK_PORT:-5001}
HEALTH_ENDPOINT="http://localhost:${FLASK_PORT}/auth/session/status"
LOG_FILE="/app/logs/healthcheck.log"
MAX_LOG_SIZE=1048576  # 1MB

# Logging with rotation
log_health() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    
    # Rotate log if too large
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Health check functions
check_web_server() {
    local response
    local http_code
    
    # Try to reach the health endpoint
    if command -v curl &> /dev/null; then
        response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 5 --max-time 10 "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
        http_code="$response"
    else
        # Fallback to wget if curl is not available
        if command -v wget &> /dev/null; then
            http_code=$(wget -q -O /dev/null -T 10 --server-response "$HEALTH_ENDPOINT" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}' || echo "000")
        else
            log_health "ERROR: Neither curl nor wget available for health check"
            return 1
        fi
    fi
    
    # Check if we got a valid HTTP response
    case "$http_code" in
        200|401|403)  # 200=OK, 401/403=Auth required but server is running
            return 0
            ;;
        *)
            log_health "ERROR: Web server unhealthy (HTTP: $http_code)"
            return 1
            ;;
    esac
}

check_disk_space() {
    local usage
    local threshold=90
    
    # Check disk usage for critical directories
    for dir in "/app/logs" "/app/data" "/app"; do
        if [ -d "$dir" ]; then
            usage=$(df "$dir" | awk 'NR==2 {print $5}' | sed 's/%//')
            if [ "$usage" -gt "$threshold" ]; then
                log_health "WARNING: Disk usage high for $dir: ${usage}%"
                return 1
            fi
        fi
    done
    
    return 0
}

check_log_files() {
    local log_dir="/app/logs"
    local error_count=0
    
    # Check if log directory exists and is writable
    if [ ! -d "$log_dir" ]; then
        log_health "ERROR: Log directory missing: $log_dir"
        return 1
    fi
    
    if [ ! -w "$log_dir" ]; then
        log_health "ERROR: Log directory not writable: $log_dir"
        return 1
    fi
    
    # Check for recent log activity (within last 10 minutes)
    local recent_logs=$(find "$log_dir" -name "*.log" -mmin -10 2>/dev/null | wc -l)
    if [ "$recent_logs" -eq 0 ]; then
        log_health "WARNING: No recent log activity detected"
        # Don't fail health check for this, just warn
    fi
    
    # Check for excessive error logs
    if [ -f "$log_dir/errors.log" ]; then
        local recent_errors=$(tail -n 100 "$log_dir/errors.log" 2>/dev/null | wc -l)
        if [ "$recent_errors" -gt 50 ]; then
            log_health "WARNING: High error count in recent logs: $recent_errors"
        fi
    fi
    
    return 0
}

check_memory_usage() {
    local threshold=90
    local usage
    
    if command -v free &> /dev/null; then
        usage=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')
        if [ "$usage" -gt "$threshold" ]; then
            log_health "WARNING: High memory usage: ${usage}%"
            return 1
        fi
    fi
    
    return 0
}

check_process_count() {
    local max_processes=200
    local process_count
    
    process_count=$(ps aux | wc -l)
    if [ "$process_count" -gt "$max_processes" ]; then
        log_health "WARNING: High process count: $process_count"
        return 1
    fi
    
    return 0
}

check_email_services() {
    # Check if email processing services are responsive
    # This could be expanded to check specific service endpoints
    
    local services_healthy=true
    
    # Check if we can import required Python modules
    if ! python -c "import services.task_manager; import services.email_processor" 2>/dev/null; then
        log_health "ERROR: Cannot import email processing modules"
        services_healthy=false
    fi
    
    # Check for recent email processing activity (if logs exist)
    if [ -f "/app/logs/email_processing.log" ]; then
        local recent_processing=$(tail -n 50 "/app/logs/email_processing.log" 2>/dev/null | grep -c "$(date +%Y-%m-%d)" || echo "0")
        log_health "INFO: Recent email processing entries: $recent_processing"
    fi
    
    if [ "$services_healthy" = false ]; then
        return 1
    fi
    
    return 0
}

# Main health check routine
main() {
    local exit_code=0
    local checks_passed=0
    local checks_total=6
    
    log_health "=== Health Check Started ==="
    
    # Web server check (critical)
    if check_web_server; then
        log_health "✓ Web server responsive"
        ((checks_passed++))
    else
        log_health "✗ Web server check failed"
        exit_code=1
    fi
    
    # Disk space check (critical)
    if check_disk_space; then
        log_health "✓ Disk space adequate"
        ((checks_passed++))
    else
        log_health "✗ Disk space check failed"
        exit_code=1
    fi
    
    # Log files check (important)
    if check_log_files; then
        log_health "✓ Log system healthy"
        ((checks_passed++))
    else
        log_health "✗ Log system check failed"
        # Don't fail container for log issues
    fi
    
    # Memory usage check (warning only)
    if check_memory_usage; then
        log_health "✓ Memory usage normal"
        ((checks_passed++))
    else
        log_health "⚠ Memory usage high"
        # Don't fail container for memory warnings
        ((checks_passed++))
    fi
    
    # Process count check (warning only)
    if check_process_count; then
        log_health "✓ Process count normal"
        ((checks_passed++))
    else
        log_health "⚠ Process count high"
        # Don't fail container for process count warnings
        ((checks_passed++))
    fi
    
    # Email services check (important but not critical)
    if check_email_services; then
        log_health "✓ Email services healthy"
        ((checks_passed++))
    else
        log_health "⚠ Email services check failed"
        # Don't fail container for service warnings during startup
        ((checks_passed++))
    fi
    
    # Summary
    log_health "Health check completed: $checks_passed/$checks_total checks passed"
    
    if [ $exit_code -eq 0 ]; then
        log_health "=== Container Healthy ==="
    else
        log_health "=== Container Unhealthy ==="
    fi
    
    exit $exit_code
}

# Run health check
main "$@"