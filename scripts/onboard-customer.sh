#!/bin/bash
# Customer Onboarding Automation Script for Mail-Rulez
# Creates DNS, deploys customer instance, configures reverse proxy
# 
# Usage: ./onboard-customer.sh <customer-name>
# Future: Can be called from Stripe webhook or sales system

set -e

# Configuration
CLOUDFLARE_TOKEN="1ISzvJKL-IJKRsI6OjKJc-USOZgTPs7PVUr6bowc"
CLOUDFLARE_ZONE_ID="254ccc5ce613734f6fdc7d8feca852a8"
TARGET_IP="104.225.217.24"
REPO_URL="https://github.com/Real-PM/mail-rulez"
BRANCH="master"
BASE_DIR="/opt/mail-rulez/customers"
CADDYFILE="/opt/caddy/Caddyfile"
CADDY_COMPOSE="/opt/docker-compose.yml"
LOG_FILE="/var/log/mail-rulez-onboard.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    logger -t "mail-rulez-onboard" "INFO: $1"
    log_to_file "INFO" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    logger -t "mail-rulez-onboard" "WARN: $1"
    log_to_file "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    logger -t "mail-rulez-onboard" "ERROR: $1"
    log_to_file "ERROR" "$1"
}

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
    logger -t "mail-rulez-onboard" "SUCCESS: $1"
    log_to_file "SUCCESS" "$1"
}

# Cleanup function for rollback
cleanup_on_failure() {
    local customer="$1"
    log_error "Deployment failed. Starting cleanup..."
    
    # Stop and remove container
    docker stop "${customer}-mail-rulez" 2>/dev/null || true
    docker rm "${customer}-mail-rulez" 2>/dev/null || true
    
    # Remove from Caddyfile
    if [ -f "${CADDYFILE}.backup" ]; then
        log_info "Restoring Caddyfile from backup"
        cp "${CADDYFILE}.backup" "$CADDYFILE"
        docker exec system-caddy caddy reload --config /etc/caddy/Caddyfile 2>/dev/null || true
    fi
    
    # Remove customer directory
    if [ -d "$BASE_DIR/$customer" ]; then
        log_info "Removing customer directory"
        rm -rf "$BASE_DIR/$customer"
    fi
    
    # Remove DNS record (optional - might want to keep for retry)
    log_warn "DNS record for ${customer}.mail-rulez.com still exists - remove manually if needed"
    
    log_error "Cleanup completed. Check logs for details."
}

# Validation functions
validate_customer_name() {
    local customer="$1"
    
    # Check if provided
    if [ -z "$customer" ]; then
        log_error "Customer name is required"
        echo "Usage: $0 <customer-name>"
        exit 1
    fi
    
    # Check format (lowercase alphanumeric, hyphens allowed)
    if ! echo "$customer" | grep -qE '^[a-z0-9-]+$'; then
        log_error "Invalid customer name: $customer"
        log_error "Must be lowercase alphanumeric with hyphens only"
        exit 1
    fi
    
    # Check if already exists
    if [ -d "$BASE_DIR/$customer" ]; then
        log_error "Customer '$customer' already exists at $BASE_DIR/$customer"
        exit 1
    fi
    
    # Check if DNS already exists
    local existing_dns=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=${customer}.mail-rulez.com" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result | length')
    
    if [ "$existing_dns" != "0" ]; then
        log_error "DNS record for ${customer}.mail-rulez.com already exists"
        exit 1
    fi
}

# DNS creation function
create_dns_record() {
    local customer="$1"
    local domain="${customer}.mail-rulez.com"
    
    log_info "Creating DNS A record: $domain -> $TARGET_IP"
    
    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "type": "A",
            "name": "'$customer'",
            "content": "'$TARGET_IP'",
            "ttl": 300,
            "proxied": false
        }')
    
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        local errors=$(echo "$response" | jq -r '.errors[]?.message // "Unknown error"')
        log_error "Failed to create DNS record: $errors"
        exit 1
    fi
    
    log_success "DNS record created successfully"
    
    # Wait for DNS propagation
    log_info "Waiting 30 seconds for DNS propagation..."
    sleep 30
}

# Directory and repo setup
setup_customer_directory() {
    local customer="$1"
    local customer_dir="$BASE_DIR/$customer"
    
    log_info "Creating customer directory: $customer_dir"
    
    # Create directory structure
    mkdir -p "$customer_dir"
    chown jayco:jayco "$customer_dir"
    
    # Clone repository
    log_info "Cloning repository to $customer_dir/app"
    cd "$customer_dir"
    sudo -u jayco gh repo clone "$REPO_URL" app
    cd app
    sudo -u jayco git checkout "$BRANCH"
    
    log_success "Repository cloned successfully"
}

# Modify docker-compose for customer
modify_docker_compose() {
    local customer="$1"
    local compose_file="$BASE_DIR/$customer/app/docker/docker-compose.simple.yml"
    local container_name="${customer}-mail-rulez"
    
    log_info "Modifying docker-compose for container name: $container_name"
    
    # Create backup
    cp "$compose_file" "${compose_file}.backup"
    
    # Replace container name and volume names to avoid conflicts
    sed -i "s/container_name: mail-rulez-simple/container_name: $container_name/" "$compose_file"
    sed -i "s/mail_rulez_/mail_rulez_${customer}_/g" "$compose_file"
    
    # Make sure jayco owns the file
    chown jayco:jayco "$compose_file"
    
    log_success "Docker compose modified successfully"
}

# Update Caddyfile
update_caddyfile() {
    local customer="$1"
    local domain="${customer}.mail-rulez.com"
    local container_name="${customer}-mail-rulez"
    
    log_info "Updating Caddyfile for $domain"
    
    # Create backup
    cp "$CADDYFILE" "${CADDYFILE}.backup"
    
    # Add new site block
    cat >> "$CADDYFILE" << EOF

$domain {
    reverse_proxy $container_name:5001
}
EOF
    
    log_success "Caddyfile updated successfully"
}

# Deploy customer container
deploy_customer() {
    local customer="$1"
    local customer_dir="$BASE_DIR/$customer/app/docker"
    local container_name="${customer}-mail-rulez"
    
    log_info "Deploying customer container: $container_name"
    
    # Change to customer directory and deploy
    cd "$customer_dir"
    
    # Modify the deployment script to use our container name
    local deploy_script="deploy-simple.sh"
    cp "$deploy_script" "${deploy_script}.backup"
    
    # Update container name in deploy script
    sed -i "s/CONTAINER_NAME=\"mail-rulez-simple\"/CONTAINER_NAME=\"$container_name\"/" "$deploy_script"
    
    # Make executable and run as jayco
    chmod +x "$deploy_script"
    
    # Run deployment
    sudo -u jayco ./"$deploy_script"
    
    # Connect to caddy network
    log_info "Connecting container to caddy-network"
    docker network connect caddy-network "$container_name"
    
    log_success "Customer container deployed successfully"
}

# Reload Caddy configuration
reload_caddy() {
    log_info "Reloading Caddy configuration"
    
    if docker exec system-caddy caddy reload --config /etc/caddy/Caddyfile; then
        log_success "Caddy configuration reloaded successfully"
    else
        log_error "Failed to reload Caddy configuration"
        return 1
    fi
}

# Health check
perform_health_check() {
    local customer="$1"
    local domain="${customer}.mail-rulez.com"
    local container_name="${customer}-mail-rulez"
    
    log_info "Performing health checks..."
    
    # Check container is running
    if ! docker ps | grep -q "$container_name"; then
        log_error "Container $container_name is not running"
        return 1
    fi
    
    # Check container health
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
    if [ "$health_status" = "healthy" ]; then
        log_success "Container health check: healthy"
    else
        log_warn "Container health check: $health_status (may still be starting)"
    fi
    
    # Test local connection
    sleep 10
    if curl -f -s "http://localhost:5001/auth/session/status" > /dev/null 2>&1; then
        log_success "Local service responding"
    else
        log_warn "Local service not yet responding (container may still be starting)"
    fi
    
    # Test domain connection (may take time for DNS/SSL)
    log_info "Testing domain access (this may take a few minutes for SSL certificate generation)..."
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --connect-timeout 10 "https://$domain/auth/session/status" > /dev/null 2>&1; then
            log_success "Domain $domain is accessible via HTTPS"
            break
        elif curl -f -s --connect-timeout 10 "http://$domain/auth/session/status" > /dev/null 2>&1; then
            log_success "Domain $domain is accessible via HTTP (SSL cert still generating)"
            break
        else
            log_info "Attempt $attempt/$max_attempts: Domain not yet accessible, waiting 30 seconds..."
            sleep 30
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "Domain not accessible after 6 minutes - may need manual checking"
        log_warn "This is normal for new domains due to DNS propagation and SSL certificate generation"
    fi
}

# Generate customer credentials (for future use)
generate_customer_info() {
    local customer="$1"
    local domain="${customer}.mail-rulez.com"
    local info_file="$BASE_DIR/$customer/customer-info.txt"
    
    log_info "Generating customer information file"
    
    # Generate version info
    local version_info="Unknown"
    if [ -f "$BASE_DIR/$customer/app/scripts/generate_version.py" ]; then
        version_info=$(cd "$BASE_DIR/$customer/app" && python3 scripts/generate_version.py 2>/dev/null | grep "Full Version:" | cut -d' ' -f3 || echo "Unknown")
    fi
    
    cat > "$info_file" << EOF
Customer: $customer
Domain: $domain
Container: ${customer}-mail-rulez
Version: $version_info
Deployed: $(date)
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
EOF
    
    chown jayco:jayco "$info_file"
    log_success "Customer info saved to $info_file"
}

# Main function
main() {
    local customer="$1"
    
    # Initialize log file (create if doesn't exist, set permissions)
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log_info "=== Mail-Rulez Customer Onboarding ==="
    log_info "Customer: $customer"
    log_info "Domain: ${customer}.mail-rulez.com"
    log_info "Started at: $(date)"
    log_info "Process ID: $"
    
    # Set up error handling
    trap 'cleanup_on_failure "$customer"' ERR
    
    # Prerequisites check
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed (required for API calls)"
        exit 1
    fi
    
    if ! sudo -u jayco gh auth status &> /dev/null; then
        log_error "GitHub CLI not authenticated for user jayco"
        exit 1
    fi
    
    # Validation
    validate_customer_name "$customer"
    
    # Execute deployment steps
    create_dns_record "$customer"
    setup_customer_directory "$customer"
    modify_docker_compose "$customer"
    update_caddyfile "$customer"
    deploy_customer "$customer"
    reload_caddy
    perform_health_check "$customer"
    generate_customer_info "$customer"
    
    # Success!
    log_success "=== Customer Onboarding Complete ==="
    log_success "Customer: $customer"
    log_success "Access URL: https://${customer}.mail-rulez.com"
    log_success "Container: ${customer}-mail-rulez"
    log_success "Local directory: $BASE_DIR/$customer"
    log_success "Completed at: $(date)"
    
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Customer can access their instance at: https://${customer}.mail-rulez.com"
    echo "2. Initial setup and account creation will be required"
    echo "3. All data is persistent in Docker volumes"
    echo "4. Customer info saved to: $BASE_DIR/$customer/customer-info.txt"
    
    # Disable error trap since we succeeded
    trap - ERR
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
