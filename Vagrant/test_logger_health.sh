#!/usr/bin/env bash
# DetectionLab Logger Health Check Script
# Tests all services and components after provisioning

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOGGER_IP="192.168.56.105"
TIMEOUT=30

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test SSH connectivity
test_ssh() {
    log_info "Testing SSH connectivity to logger..."
    
    local retry_count=0
    local max_retries=10
    
    while [ $retry_count -lt $max_retries ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no vagrant@$LOGGER_IP "echo 'SSH connection successful'" 2>/dev/null; then
            log_success "SSH connection established"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warning "SSH connection failed, retrying in 5s... (attempt $retry_count/$max_retries)"
            sleep 5
        fi
    done
    
    log_error "SSH connection failed after $max_retries attempts"
    return 1
}

# Test HTTP services
test_http_service() {
    local service_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    log_info "Testing $service_name at $url..."
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$url" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "$expected_status" ]; then
        log_success "$service_name is responding correctly (HTTP $response_code)"
        return 0
    else
        log_error "$service_name is not responding correctly (HTTP $response_code)"
        return 1
    fi
}

# Test HTTPS services
test_https_service() {
    local service_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    log_info "Testing $service_name at $url..."
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT -k "$url" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "$expected_status" ]; then
        log_success "$service_name is responding correctly (HTTP $response_code)"
        return 0
    else
        log_error "$service_name is not responding correctly (HTTP $response_code)"
        return 1
    fi
}

# Test service via SSH
test_service_ssh() {
    local service_name="$1"
    local service_command="$2"
    
    log_info "Testing $service_name service via SSH..."
    
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no vagrant@$LOGGER_IP "$service_command" 2>/dev/null; then
        log_success "$service_name service is running"
        return 0
    else
        log_error "$service_name service is not running"
        return 1
    fi
}

# Test port connectivity
test_port() {
    local port="$1"
    local service_name="$2"
    
    log_info "Testing port $port for $service_name..."
    
    if nc -z -w5 $LOGGER_IP $port 2>/dev/null; then
        log_success "Port $port is open for $service_name"
        return 0
    else
        log_error "Port $port is not accessible for $service_name"
        return 1
    fi
}

# Main health check function
main() {
    echo "==============================================="
    echo "    DetectionLab Logger Health Check"
    echo "==============================================="
    echo "Target: $LOGGER_IP"
    echo "Timestamp: $(date)"
    echo ""
    
    local failed_tests=0
    
    # Test SSH connectivity
    if ! test_ssh; then
        log_error "Cannot proceed with health checks - SSH connection failed"
        exit 1
    fi
    
    echo ""
    log_info "Starting service health checks..."
    echo ""
    
    # Test Splunk
    if ! test_https_service "Splunk Web Interface" "https://$LOGGER_IP:8000"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    # Test Fleet
    if ! test_https_service "Fleet osquery Manager" "https://$LOGGER_IP:8412"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    # Test Guacamole
    if ! test_http_service "Apache Guacamole" "http://$LOGGER_IP:8080/guacamole"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    # Test Velociraptor
    if ! test_https_service "Velociraptor" "https://$LOGGER_IP:9999"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
    log_info "Starting service status checks..."
    echo ""
    
    # Test services via SSH
    if ! test_service_ssh "Zeek" "systemctl is-active --quiet zeek"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_service_ssh "Suricata" "systemctl is-active --quiet suricata"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_service_ssh "Fleet" "systemctl is-active --quiet fleet"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_service_ssh "Tomcat9" "systemctl is-active --quiet tomcat9"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
    log_info "Starting port connectivity checks..."
    echo ""
    
    # Test critical ports
    if ! test_port "8000" "Splunk"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_port "8412" "Fleet"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_port "8080" "Guacamole"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    if ! test_port "9999" "Velociraptor"; then
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
    echo "==============================================="
    echo "           Health Check Summary"
    echo "==============================================="
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All health checks passed! Logger is fully operational."
        echo ""
        echo "Access URLs:"
        echo "  - Splunk: https://$LOGGER_IP:8000 (admin:changeme)"
        echo "  - Fleet: https://$LOGGER_IP:8412 (admin@detectionlab.network:Fl33tpassword!)"
        echo "  - Guacamole: http://$LOGGER_IP:8080/guacamole (vagrant:vagrant)"
        echo "  - Velociraptor: https://$LOGGER_IP:9999 (admin:changeme)"
        echo ""
        exit 0
    else
        log_error "$failed_tests health check(s) failed. Logger may need attention."
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Check service status: ssh vagrant@$LOGGER_IP 'systemctl status <service>'"
        echo "  2. Restart failed services: ssh vagrant@$LOGGER_IP 'systemctl restart <service>'"
        echo "  3. Check logs: ssh vagrant@$LOGGER_IP 'journalctl -u <service> -f'"
        echo ""
        exit 1
    fi
}

# Run main function
main "$@"
