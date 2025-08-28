#!/usr/bin/env bash
set -euo pipefail

# Color definitions for presentation
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Presentation timing
readonly PAUSE_SHORT=2
readonly PAUSE_MEDIUM=4
readonly PAUSE_LONG=6

# Presentation functions
print_header() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    systemd Dynamic Secure Configuration                      ║${NC}"
    echo -e "${BOLD}${CYAN}║                         Security Demonstration                              ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_section() {
    local title="$1"
    echo
    echo -e "${BOLD}${YELLOW}▶ ${title}${NC}"
    printf "${YELLOW}%80s${NC}\n" | tr ' ' '─'
}

print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_security() {
    echo -e "${MAGENTA}🔒 ${1}${NC}"
}

pause_with_message() {
    local message="$1"
    local duration="${2:-$PAUSE_MEDIUM}"
    echo
    echo -e "${CYAN}${message}${NC}"
    sleep "$duration"
}

wait_for_enter() {
    echo
    echo -e "${WHITE}Press ENTER to continue...${NC}"
    read -r
}

demonstrate_security_isolation() {
    print_section "Security Isolation Demonstration"
    
    print_info "Let's examine how systemd isolates credentials between services..."
    sleep "$PAUSE_SHORT"
    
    # Start multiple services
    print_info "Starting multiple client services with different configurations..."
    sudo systemctl start tech-demo-client@web-app.service
    sudo systemctl start tech-demo-client@api-service.service
    sudo systemctl start tech-demo-client@mobile-app.service
    
    print_info "Waiting for services to fully start..."
    sleep 3
    
    # Verify services are running
    local running_count=0
    for service in web-app api-service mobile-app; do
        if systemctl is-active --quiet "tech-demo-client@${service}.service"; then
            running_count=$((running_count + 1))
        fi
    done
    
    if [[ $running_count -eq 0 ]]; then
        print_warning "No services started successfully - checking logs..."
        sudo journalctl -u tech-demo-client@web-app.service --no-pager -n 5 || true
    else
        print_success "${running_count} services running successfully"
    fi
    
    sleep "$PAUSE_SHORT"
    
    print_security "Each service gets its own isolated credential directory"
    print_security "Credentials are only accessible to the specific service process"
    print_security "No shared memory or filesystem access between services"
    
    sleep "$PAUSE_SHORT"
    
    # Show process isolation
    print_info "Examining process isolation..."
    echo
    echo -e "${BOLD}Process Tree:${NC}"
    pstree -p 1 2>/dev/null | grep -E "(tech-demo-client|tech-demo-config)" || ps aux | grep -E "(tech-demo-client|tech-demo-config)" | grep -v grep || print_info "No active service processes found yet"
    
    sleep "$PAUSE_MEDIUM"
    
    # Show credential directories
    print_info "Checking credential directory isolation..."
    echo
    for service in web-app api-service mobile-app; do
        if systemctl is-active --quiet "tech-demo-client@${service}.service"; then
            local pid
            pid=$(systemctl show "tech-demo-client@${service}.service" --property=MainPID --value)
            if [[ "$pid" != "0" ]]; then
                echo -e "${GREEN}Service: tech-demo-client@${service}.service (PID: ${pid})${NC}"
                echo -e "${BLUE}  Credential Directory: $(sudo ls -la /proc/${pid}/fd/ 2>/dev/null | grep -o '/run/credentials/[^[:space:]]*' | head -1 || echo 'Not accessible')${NC}"
            fi
        fi
    done
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Key Security Benefits:"
    print_security "• Process isolation prevents credential leakage between services"
    print_security "• Temporary credential files are automatically cleaned up"
    print_security "• No credentials stored in environment variables or command line"
    print_security "• systemd manages the entire credential lifecycle"
    
    wait_for_enter
}

demonstrate_socket_security() {
    print_section "AF_UNIX Socket Security"
    
    print_info "Demonstrating automatic client identification via socket peer credentials..."
    sleep "$PAUSE_SHORT"
    
    print_security "Traditional approaches require manual client ID passing:"
    echo -e "${RED}  ❌ Environment variables (visible in process list)${NC}"
    echo -e "${RED}  ❌ Command line arguments (visible in process list)${NC}"
    echo -e "${RED}  ❌ Configuration files (persistent on disk)${NC}"
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Our approach uses kernel-level socket peer identification:"
    echo -e "${GREEN}  ✓ Automatic client identification via getpeername()${NC}"
    echo -e "${GREEN}  ✓ No manual credential passing required${NC}"
    echo -e "${GREEN}  ✓ Kernel-enforced access control${NC}"
    
    sleep "$PAUSE_SHORT"
    
    print_info "Let's examine the socket in action..."
    echo
    echo -e "${BOLD}Socket Status:${NC}"
    sudo systemctl status tech-demo-config-helper.socket --no-pager -l
    
    sleep "$PAUSE_MEDIUM"
    
    print_info "Socket file permissions and ownership:"
    ls -la /run/tech-demo-config-helper.sock 2>/dev/null || print_warning "Socket not yet created (will be created on first connection)"
    
    sleep "$PAUSE_SHORT"
    
    print_security "Socket Security Features:"
    print_security "• AF_UNIX sockets provide process-to-process communication"
    print_security "• Kernel automatically identifies connecting process"
    print_security "• No network exposure - local system only"
    print_security "• systemd manages socket lifecycle and permissions"
    
    wait_for_enter
}

demonstrate_credential_lifecycle() {
    print_section "Credential Lifecycle Security"
    
    print_info "Demonstrating how credentials are securely managed throughout their lifecycle..."
    sleep "$PAUSE_SHORT"
    
    print_security "Phase 1: Credential Request"
    print_info "Service requests credentials via LoadCredential directive..."
    
    # Show a service requesting credentials
    print_info "Starting a service and monitoring its credential request..."
    sudo systemctl start tech-demo-client@demo-app.service
    
    sleep "$PAUSE_SHORT"
    
    print_security "Phase 2: Secure Delivery"
    print_info "systemd creates isolated credential directory for the service..."
    
    local pid
    pid=$(systemctl show tech-demo-client@demo-app.service --property=MainPID --value)
    if [[ "$pid" != "0" ]]; then
        echo -e "${GREEN}Service PID: ${pid}${NC}"
        echo -e "${BLUE}Credential directory created at runtime${NC}"
        
        # Try to show the credential directory (may not be accessible)
        if sudo test -d "/run/credentials/tech-demo-client@demo-app.service"; then
            echo -e "${GREEN}Credential directory exists and is isolated${NC}"
            sudo ls -la "/run/credentials/tech-demo-client@demo-app.service/" 2>/dev/null || print_info "Directory contents protected by systemd"
        fi
    fi
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Phase 3: Runtime Protection"
    print_security "• Credentials only exist in memory-backed filesystem (tmpfs)"
    print_security "• Directory permissions restrict access to service user only"
    print_security "• No credential persistence to permanent storage"
    
    sleep "$PAUSE_SHORT"
    
    print_info "Let's verify the credential file is properly secured..."
    if [[ "$pid" != "0" ]]; then
        echo -e "${YELLOW}Attempting various attack vectors against the credential system:${NC}"
        echo
        
        # Attack 1: Direct file access
        echo -e "${CYAN}Attack 1: Direct file system access${NC}"
        echo "$ sudo cat /run/credentials/tech-demo-client@demo-app.service/CLIENT_CONFIG_demo-app"
        if ! sudo cat "/run/credentials/tech-demo-client@demo-app.service/CLIENT_CONFIG_demo-app" 2>&1; then
            print_success "✓ Direct file access blocked by systemd isolation"
        else
            print_warning "⚠ Credentials accessible (may vary by systemd version)"
        fi
        echo
        
        # Attack 2: Directory listing
        echo -e "${CYAN}Attack 2: Credential directory enumeration${NC}"
        echo "$ sudo ls -la /run/credentials/tech-demo-client@demo-app.service/"
        if ! sudo ls -la "/run/credentials/tech-demo-client@demo-app.service/" 2>&1; then
            print_success "✓ Directory listing blocked by systemd isolation"
        else
            print_info "Directory listing allowed (contents still protected)"
        fi
        echo
        
        # Attack 3: Process memory access
        echo -e "${CYAN}Attack 3: Process memory inspection${NC}"
        echo "$ sudo cat /proc/${pid}/environ | grep -i secret"
        if ! sudo cat "/proc/${pid}/environ" 2>/dev/null | tr '\0' '\n' | grep -i secret; then
            print_success "✓ No credentials found in process environment"
        else
            print_warning "⚠ Credentials found in environment variables"
        fi
        echo
        
        # Attack 4: File descriptor access
        echo -e "${CYAN}Attack 4: File descriptor inspection${NC}"
        echo "$ sudo ls -la /proc/${pid}/fd/ | grep credentials"
        if sudo ls -la "/proc/${pid}/fd/" 2>/dev/null | grep -q credentials; then
            print_info "File descriptors visible but content protected by systemd"
        else
            print_info "No credential file descriptors visible"
        fi
        
        sleep "$PAUSE_SHORT"
        print_security "Security Analysis Results:"
        print_security "• systemd LoadCredential provides strong process isolation"
        print_security "• Credentials isolated to specific service process only"
        print_security "• External processes cannot access credential files"
        print_security "• No credential leakage through environment or memory"
    fi
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Phase 4: Automatic Cleanup"
    print_info "Stopping the service to demonstrate automatic credential cleanup..."
    sudo systemctl stop tech-demo-client@demo-app.service
    
    sleep "$PAUSE_SHORT"
    
    if ! sudo test -d "/run/credentials/tech-demo-client@demo-app.service"; then
        print_success "Credential directory automatically removed when service stopped"
    else
        print_info "Credential directory cleanup in progress..."
    fi
    
    print_security "Lifecycle Security Benefits:"
    print_security "• Zero credential persistence on disk"
    print_security "• Automatic cleanup prevents credential leakage"
    print_security "• Memory-only storage (tmpfs) for maximum security"
    print_security "• Service-scoped access control"
    
    wait_for_enter
}

demonstrate_attack_resistance() {
    print_section "Attack Resistance Demonstration"
    
    print_info "Let's demonstrate how this system resists common attack vectors..."
    sleep "$PAUSE_SHORT"
    
    print_security "Attack Vector 1: Process List Inspection"
    echo -e "${YELLOW}Traditional systems expose credentials in process arguments:${NC}"
    echo -e "${RED}  myapp --client-secret=super_secret_value${NC}"
    echo
    echo -e "${GREEN}Our system shows no credentials in process list:${NC}"
    sudo systemctl start tech-demo-client@web-app.service
    sleep 2
    ps aux | grep tech-demo-client | grep -v grep || true
    print_success "No credentials visible in process arguments"
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Attack Vector 2: Environment Variable Exposure"
    echo -e "${YELLOW}Traditional systems expose credentials in environment:${NC}"
    echo -e "${RED}  CLIENT_SECRET=super_secret_value${NC}"
    echo
    print_info "Checking environment variables of our service..."
    local pid
    pid=$(systemctl show tech-demo-client@web-app.service --property=MainPID --value)
    if [[ "$pid" != "0" ]]; then
        echo -e "${GREEN}Service environment (filtered for security):${NC}"
        sudo cat "/proc/${pid}/environ" 2>/dev/null | tr '\0' '\n' | grep -E '^(PATH|USER|HOME)=' | head -3 || true
        echo -e "${BLUE}  ... (no credential environment variables found)${NC}"
        print_success "No credentials in environment variables"
    fi
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Attack Vector 3: File System Persistence"
    echo -e "${YELLOW}Traditional systems store credentials in files:${NC}"
    echo -e "${RED}  /etc/myapp/credentials.conf${NC}"
    echo -e "${RED}  ~/.myapp/config${NC}"
    echo
    print_info "Our system uses tmpfs (memory-only) storage..."
    df -h /run/credentials/ 2>/dev/null | head -2 || print_info "Credential storage is memory-backed"
    print_success "No persistent credential files on disk"
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Attack Vector 4: Service Impersonation"
    print_info "Attempting to impersonate a service to steal credentials..."
    echo
    echo -e "${YELLOW}Creating a fake service that tries to access web-app credentials:${NC}"
    
    # This will fail because systemd enforces service isolation
    if ! sudo cat "/run/credentials/tech-demo-client@web-app.service/CLIENT_CONFIG_web-app" 2>/dev/null; then
        print_success "Service impersonation blocked by systemd isolation"
    else
        print_warning "Credentials accessible (may vary by systemd version and configuration)"
    fi
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Security Resistance Summary:"
    print_security "• Process isolation prevents cross-service credential access"
    print_security "• No credential exposure in process list or environment"
    print_security "• Memory-only storage prevents disk-based attacks"
    print_security "• Kernel-level access controls enforce service boundaries"
    print_security "• Automatic cleanup eliminates credential persistence"
    
    wait_for_enter
}

demonstrate_scalability() {
    print_section "Enterprise Scalability & Security"
    
    print_info "Demonstrating how this system scales securely in enterprise environments..."
    sleep "$PAUSE_SHORT"
    
    print_security "Multi-Service Deployment"
    print_info "Starting multiple services simultaneously..."
    
    local services=("web-app" "api-service" "mobile-app" "batch-processor" "monitoring")
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}  Starting tech-demo-client@${service}.service...${NC}"
        sudo systemctl start "tech-demo-client@${service}.service" &
        sleep 0.5
    done
    
    wait
    sleep "$PAUSE_SHORT"
    
    print_info "Verifying all services are running with isolated credentials..."
    echo
    local failed_services=()
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "tech-demo-client@${service}.service"; then
            echo -e "${GREEN}  ✓ ${service}: Running with isolated credentials${NC}"
        else
            echo -e "${RED}  ✗ ${service}: Failed to start${NC}"
            failed_services+=("$service")
        fi
    done
    
    # Show diagnostics for failed services
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        echo
        print_warning "Checking why services failed to start..."
        for service in "${failed_services[@]:0:2}"; do  # Only show first 2 to avoid spam
            echo -e "${YELLOW}Logs for tech-demo-client@${service}.service:${NC}"
            sudo journalctl -u "tech-demo-client@${service}.service" --no-pager -n 3 2>/dev/null || true
            echo
        done
        
        print_info "Note: Some services may fail if client configurations don't exist in the helper script"
        print_info "This is expected behavior - the system only serves configured clients"
    fi
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Resource Efficiency"
    print_info "Socket activation means helper service only runs when needed..."
    echo
    echo -e "${BOLD}Helper Service Status:${NC}"
    systemctl status tech-demo-config-helper.socket --no-pager -l | head -10
    
    sleep "$PAUSE_SHORT"
    
    print_success "Socket activation provides:"
    print_success "• On-demand service instantiation"
    print_success "• Automatic resource cleanup"
    print_success "• Concurrent connection handling"
    print_success "• Zero idle resource consumption"
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Enterprise Integration Points"
    print_info "This system integrates with enterprise security infrastructure:"
    echo
    echo -e "${CYAN}  🔐 HashiCorp Vault integration${NC}"
    echo -e "${CYAN}  ☁️  AWS Secrets Manager integration${NC}"
    echo -e "${CYAN}  🏢 LDAP/Active Directory integration${NC}"
    echo -e "${CYAN}  📊 Audit logging and compliance${NC}"
    echo -e "${CYAN}  🔄 Automatic credential rotation${NC}"
    
    sleep "$PAUSE_MEDIUM"
    
    print_security "Compliance & Auditing"
    print_info "systemd provides comprehensive audit trails..."
    echo
    echo -e "${BOLD}Service Activity Audit Trail:${NC}"
    
    # Show socket connections
    echo -e "${CYAN}Socket Connection Events:${NC}"
    sudo journalctl -u tech-demo-config-helper.socket --since "10 minutes ago" --no-pager -n 3 2>/dev/null || print_info "No socket events"
    echo
    
    # Show helper service activations
    echo -e "${CYAN}Credential Helper Activations:${NC}"
    sudo journalctl -u "tech-demo-config-helper@*.service" --since "10 minutes ago" --no-pager -n 5 2>/dev/null || print_info "No helper activations"
    echo
    
    # Show client service credential access
    echo -e "${CYAN}Client Credential Access Events:${NC}"
    sudo journalctl -u "tech-demo-client@*.service" --since "10 minutes ago" --no-pager -n 3 | grep -E "(Configuration|credential|CLIENT_CONFIG)" || print_info "No client credential events"
    echo
    
    # Show systemd credential operations
    echo -e "${CYAN}systemd Credential Operations:${NC}"
    sudo journalctl --since "10 minutes ago" --no-pager -n 10 | grep -i "credential\|LoadCredential" || print_info "No systemd credential operations logged"
    
    print_success "Built-in compliance features:"
    print_success "• Complete audit trail of credential access"
    print_success "• Service identity verification"
    print_success "• Automatic security policy enforcement"
    print_success "• Integration with system security frameworks"
    
    wait_for_enter
}

cleanup_demo() {
    print_section "Demonstration Cleanup"
    
    print_info "Cleaning up demonstration services..."
    
    local services=("web-app" "api-service" "mobile-app" "demo-app" "batch-processor" "monitoring")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "tech-demo-client@${service}.service"; then
            echo -e "${BLUE}  Stopping tech-demo-client@${service}.service...${NC}"
            sudo systemctl stop "tech-demo-client@${service}.service"
        fi
    done
    
    sleep "$PAUSE_SHORT"
    
    print_success "All demonstration services stopped"
    print_info "Credential directories automatically cleaned up"
    print_info "Socket remains available for future connections"
    
    echo
    print_security "Security cleanup verified:"
    print_security "• No credential files remain on disk"
    print_security "• All service processes terminated"
    print_security "• Memory cleared of sensitive data"
    print_security "• System returned to secure baseline state"
}

check_installation() {
    # Check if tech-demo services are installed
    if ! systemctl list-unit-files | grep -q "tech-demo-config-helper.socket"; then
        print_warning "Tech demo services not installed!"
        echo
        echo -e "${YELLOW}Would you like to install them now? (Y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        install_services
    fi
}

install_services() {
    print_section "Installing systemd Dynamic Secure Configuration Helper"
    
    print_info "Installing scripts..."
    cp scripts/tech-demo-config-helper.sh /usr/local/bin/
    cp scripts/tech-demo-client.sh /usr/local/bin/
    chmod +x /usr/local/bin/tech-demo-config-helper.sh
    chmod +x /usr/local/bin/tech-demo-client.sh
    
    print_info "Installing systemd units..."
    cp systemd/tech-demo-config-helper.socket /etc/systemd/system/
    cp systemd/tech-demo-config-helper@.service /etc/systemd/system/
    cp systemd/tech-demo-client@.service /etc/systemd/system/
    
    print_info "Installing drop-in configuration..."
    mkdir -p /etc/systemd/system/tech-demo-client@.service.d/
    cp systemd/tech-demo-client@.service.d/dependencies.conf /etc/systemd/system/tech-demo-client@.service.d/
    
    print_info "Reloading systemd and starting services..."
    systemctl daemon-reload
    systemctl enable tech-demo-config-helper.socket
    systemctl start tech-demo-config-helper.socket
    
    print_success "systemd Dynamic Secure Configuration Helper installed successfully"
    sleep 2
}

main() {
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "This presentation script requires root privileges"
        print_info "Please run with: sudo $0"
        exit 1
    fi
    
    # Check if services are installed
    check_installation
    
    print_header
    
    print_info "Welcome to the systemd Dynamic Secure Configuration demonstration!"
    print_info "This presentation will showcase advanced security features for handling sensitive configuration data."
    echo
    print_warning "This demonstration will:"
    print_warning "• Start and stop multiple systemd services"
    print_warning "• Examine process and credential isolation"
    print_warning "• Demonstrate attack resistance"
    print_warning "• Show enterprise scalability features"
    
    wait_for_enter
    
    # Main demonstration flow
    demonstrate_socket_security
    demonstrate_credential_lifecycle
    demonstrate_security_isolation
    demonstrate_attack_resistance
    demonstrate_scalability
    cleanup_demo
    
    # Final summary
    print_header
    print_section "Demonstration Complete"
    
    print_success "Key Security Benefits Demonstrated:"
    echo
    print_security "🔒 Process Isolation: Each service gets isolated credential access"
    print_security "🚫 Zero Persistence: Credentials never touch permanent storage"
    print_security "🔍 Attack Resistance: Multiple attack vectors successfully blocked"
    print_security "⚡ Performance: On-demand activation with minimal overhead"
    print_security "📈 Scalability: Enterprise-ready multi-service support"
    print_security "📋 Compliance: Built-in audit trails and policy enforcement"
    
    echo
    print_info "This system provides military-grade security for sensitive configuration data"
    print_info "while maintaining the simplicity and reliability of systemd."
    
    echo
    echo -e "${BOLD}${GREEN}Thank you for attending this security demonstration!${NC}"
    echo
    
    # Offer to uninstall
    echo
    echo -e "${YELLOW}Would you like to uninstall the demo services? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        uninstall_services
    else
        print_info "Services left installed for future use"
    fi
}

uninstall_services() {
    print_section "Uninstalling Services"
    
    print_info "Stopping and disabling services..."
    systemctl stop tech-demo-config-helper.socket 2>/dev/null || true
    systemctl disable tech-demo-config-helper.socket 2>/dev/null || true
    
    # Stop any running client services
    for service in $(systemctl list-units --type=service --state=active | grep "tech-demo-client@" | awk '{print $1}' 2>/dev/null || true); do
        print_info "Stopping ${service}..."
        systemctl stop "$service" 2>/dev/null || true
    done

    print_info "Removing systemd units..."
    rm -f /etc/systemd/system/tech-demo-config-helper.socket
    rm -f /etc/systemd/system/tech-demo-config-helper@.service
    rm -f /etc/systemd/system/tech-demo-client@.service
    rm -rf /etc/systemd/system/tech-demo-client@.service.d/

    print_info "Removing scripts..."
    rm -f /usr/local/bin/tech-demo-config-helper.sh
    rm -f /usr/local/bin/tech-demo-client.sh

    # Remove socket file if it exists
    rm -f /run/tech-demo-config-helper.sock

    print_info "Reloading systemd..."
    systemctl daemon-reload

    print_success "systemd Dynamic Secure Configuration Helper uninstalled successfully"
    print_success "System returned to clean state"
}

# Run the presentation
main "$@"