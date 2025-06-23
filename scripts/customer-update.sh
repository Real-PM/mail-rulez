#!/bin/bash
# Customer Update Script - Updates a customer's Mail-Rulez deployment
# Usage: ./update-customer.sh <customer-name> [--all]

set -e

# Configuration
BASE_DIR="/opt/mail-rulez/customers"
REPO_URL="https://github.com/Real-PM/mail-rulez"
BRANCH="master"
LOG_FILE="/var/log/mail-rulez-updates.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_to_file "INFO" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_to_file "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "ERROR" "$1"
}

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
    log_to_file "SUCCESS" "$1"
}

# Backup function
create_backup() {
    local customer="$1"
    local backup_dir="$BASE_DIR/$customer/backups/$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup for $customer at $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup volumes (export data)
    for volume in data lists config; do
        local volume_name="mail_rulez_${customer}_${volume}"
        if docker volume inspect "$volume_name" >/dev/null 2>&1; then
            docker run --rm -v "$volume_name:/source" -v "$backup_dir:/backup" \
                alpine tar czf "/backup/${volume}.tar.gz" -C /source .
            log_info "Backed up volume: $volume_name"
        fi
    done
    
    # Backup current code
    if [ -d "$BASE_DIR/$customer/app" ]; then
        tar czf "$backup_dir/app_code.tar.gz" -C "$BASE_DIR/$customer" app
        log_info "Backed up application code"
    fi
    
    echo "$backup_dir"
}

# Update single customer
update_customer() {
    local customer="$1"
    local customer_dir="$BASE_DIR/$customer"
    local container_name="${customer}-mail-rulez"
    
    log_info "=== Updating customer: $customer ==="
    
    # Check if customer exists
    if [ ! -d "$customer_dir" ]; then
        log_error "Customer directory not found: $customer_dir"
        return 1
    fi
    
    # Check if container exists
    if ! docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        log_error "Container not found: $container_name"
        return 1
    fi
    
    # Create backup
    local backup_dir=$(create_backup "$customer")
    
    # Stop container
    log_info "Stopping container: $container_name"
    docker stop "$container_name"
    
    # Update code
    log_info "Updating code from repository"
    cd "$customer_dir/app"
    
    # Stash any local changes
    sudo -u jayco git stash push -m "Auto-stash before update $(date)"
    
    # Pull latest code
    sudo -u jayco git fetch origin
    sudo -u jayco git checkout "$BRANCH"
    sudo -u jayco git pull origin "$BRANCH"
    
    # Get commit info for logging
    local new_commit=$(git rev-parse HEAD)
    local commit_msg=$(git log -1 --pretty=format:"%s")
    log_info "Updated to commit: $new_commit"
    log_info "Commit message: $commit_msg"
    
    # Generate version information for deployment
    log_info "Generating version information"
    if [ -f "scripts/generate_version.py" ]; then
        python3 scripts/generate_version.py
        local new_version=$(python3 scripts/generate_version.py 2>/dev/null | grep "Full Version:" | cut -d' ' -f3 || echo "Unknown")
        log_info "Version: $new_version"
    fi
    
    # Modify docker-compose for customer-specific naming
    log_info "Updating docker-compose for customer: $customer"
    local compose_file="$customer_dir/app/docker/docker-compose.simple.yml"
    
    # Replace container name and volume names to match customer
    sed -i "s/container_name: mail-rulez-simple/container_name: $container_name/" "$compose_file"
    sed -i "s/mail_rulez_/mail_rulez_${customer}_/g" "$compose_file"
    
    log_info "Docker compose updated for container: $container_name"
    
    # Rebuild and restart
    log_info "Rebuilding container"
    cd "$customer_dir/app/docker"
    
    # Remove old container and rebuild
    docker rm "$container_name"
    sudo -u jayco docker compose -f docker-compose.simple.yml build --no-cache
    sudo -u jayco docker compose -f docker-compose.simple.yml up -d
    
    # Reconnect to network
    docker network connect caddy-network "$container_name"
    
    # Wait for startup
    log_info "Waiting for container to start..."
    sleep 15
    
    # Health check
    local max_attempts=6
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$container_name" curl -f -s "http://localhost:5001/auth/session/status" >/dev/null 2>&1; then
            log_success "Container $container_name is healthy"
            break
        else
            log_info "Health check attempt $attempt/$max_attempts failed, waiting..."
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Container failed health check. Rolling back..."
        
        # Rollback: stop container and restore from backup
        docker stop "$container_name" || true
        docker rm "$container_name" || true
        
        # Restore volumes
        for volume in data lists config; do
            local volume_name="mail_rulez_${customer}_${volume}"
            if [ -f "$backup_dir/${volume}.tar.gz" ]; then
                docker volume rm "$volume_name" || true
                docker volume create "$volume_name"
                docker run --rm -v "$volume_name:/target" -v "$backup_dir:/backup" \
                    alpine tar xzf "/backup/${volume}.tar.gz" -C /target
                log_info "Restored volume: $volume_name"
            fi
        done
        
        # Restore code
        cd "$customer_dir"
        rm -rf app
        tar xzf "$backup_dir/app_code.tar.gz"
        
        # Restart with old version
        cd "$customer_dir/app/docker"
        sudo -u jayco docker compose -f docker-compose.simple.yml up -d
        docker network connect caddy-network "$container_name"
        
        log_error "Rollback completed. Check logs for issues."
        return 1
    fi
    
    # Update successful
    log_success "Update completed successfully for $customer"
    log_info "Backup available at: $backup_dir"
    
    # Update customer info file with new version
    log_info "Updating customer information file"
    local domain="${customer}.mail-rulez.com"
    local info_file="$customer_dir/customer-info.txt"
    local version_info="Unknown"
    if [ -f "$customer_dir/app/scripts/generate_version.py" ]; then
        version_info=$(cd "$customer_dir/app" && python3 scripts/generate_version.py 2>/dev/null | grep "Full Version:" | cut -d' ' -f3 || echo "Unknown")
    fi
    
    cat > "$info_file" << EOF
Customer: $customer
Domain: $domain
Container: ${customer}-mail-rulez
Version: $version_info
Updated: $(date)
Access URL: https://$domain

Management Commands:
- View logs: docker logs ${customer}-mail-rulez
- Restart: cd $BASE_DIR/$customer/app/docker && docker compose -f docker-compose.simple.yml restart
- Stop: cd $BASE_DIR/$customer/app/docker && docker compose -f docker-compose.simple.yml down

Volume Names:
- mail_rulez_${customer}_data
- mail_rulez_${customer}_lists
- mail_rulez_${customer}_logs
- mail_rulez_${customer}_backups
- mail_rulez_${customer}_config

Last Update Info:
- Commit: $new_commit
- Backup: $backup_dir
EOF
    
    # Log update info
    echo "Customer: $customer" > "$customer_dir/last-update.txt"
    echo "Updated: $(date)" >> "$customer_dir/last-update.txt"
    echo "Version: $version_info" >> "$customer_dir/last-update.txt"
    echo "Commit: $new_commit" >> "$customer_dir/last-update.txt"
    echo "Backup: $backup_dir" >> "$customer_dir/last-update.txt"
    
    return 0
}

# Update all customers
update_all_customers() {
    log_info "=== Updating all customers ==="
    
    local success_count=0
    local failure_count=0
    local failed_customers=()
    
    for customer_dir in "$BASE_DIR"/*; do
        if [ -d "$customer_dir" ]; then
            local customer=$(basename "$customer_dir")
            log_info "Processing customer: $customer"
            
            if update_customer "$customer"; then
                ((success_count++))
            else
                ((failure_count++))
                failed_customers+=("$customer")
            fi
            
            # Small delay between updates
            sleep 5
        fi
    done
    
    log_info "=== Update Summary ==="
    log_success "Successful updates: $success_count"
    if [ $failure_count -gt 0 ]; then
        log_error "Failed updates: $failure_count"
        log_error "Failed customers: ${failed_customers[*]}"
    fi
}

# Main function
main() {
    local customer="$1"
    local update_all="$2"
    
    # Initialize log
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log_info "=== Mail-Rulez Update Process Started ==="
    log_info "Started at: $(date)"
    
    if [ "$customer" = "--all" ] || [ "$update_all" = "--all" ]; then
        update_all_customers
    elif [ -n "$customer" ]; then
        update_customer "$customer"
    else
        echo "Usage: $0 <customer-name> | --all"
        echo "Examples:"
        echo "  $0 kord              # Update specific customer"
        echo "  $0 --all             # Update all customers"
        exit 1
    fi
    
    log_info "=== Update Process Complete ==="
}

# Entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
