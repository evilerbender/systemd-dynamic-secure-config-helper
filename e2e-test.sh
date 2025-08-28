#!/usr/bin/env bash
#
# End-to-End Test Script for Tech Demo Config Helper
# Purpose: Complete installation, testing, and cleanup cycle
# Usage: sudo ./e2e-test.sh
#
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_LOG="/tmp/tech-demo-config-helper-e2e.log"
readonly BACKUP_DIR="/tmp/tech-demo-config-helper-backup"

# Test results tracking
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Files that will be installed
readonly INSTALLED_FILES=(
    "/usr/local/bin/tech-demo-config-helper.sh"
    "/usr/local/bin/tech-demo-client.sh"
    "/etc/systemd/system/tech-demo-config-helper.socket"
    "/etc/systemd/system/tech-demo-config-helper@.service"
    "/etc/systemd/system/tech-demo-client@.service"
    "/etc/systemd/system/tech-demo-client@.service.d/dependencies.conf"
)

# Directories that will be created
readonly INSTALLED_DIRS=(
    "/etc/systemd/system/tech-demo-client@.service.d"
)

# Services that will be created
readonly SERVICES=(
    "tech-demo-config-helper.socket"
    "tech-demo-config-helper@.service"
    "tech-demo-client@.service"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${TEST_LOG}"
}

verbose() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "${TEST_LOG}"
}

step() {
    echo "" | tee -a "${TEST_LOG}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $*" | tee -a "${TEST_LOG}"
    echo "----------------------------------------" | tee -a "${TEST_LOG}"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${TEST_LOG}" >&2
}

test_result() {
    local -r test_name="$1"
    local -r result="$2"
    
    if [[ "${result}" == "PASS" ]]; then
        log "✓ ${test_name}: PASS"
        ((TESTS_PASSED++))
    else
        log "✗ ${test_name}: FAIL"
        ((TESTS_FAILED++))
        FAILED_TESTS+=("${test_name}")
    fi
}

check_prerequisites() {
    step "Checking prerequisites"
    
    verbose "Checking if running as root..."
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    verbose "✓ Running as root (UID: $EUID)"
    
    verbose "Checking for systemctl command..."
    if ! command -v systemctl >/dev/null 2>&1; then
        error "systemctl not found - systemd required"
        exit 1
    fi
    verbose "✓ systemctl found at: $(command -v systemctl)"
    
    verbose "Checking systemd version..."
    local systemd_version
    systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
    verbose "✓ systemd version: ${systemd_version}"
    
    verbose "Checking required files exist..."
    for file in scripts/tech-demo-config-helper.sh scripts/tech-demo-client.sh systemd/tech-demo-config-helper.socket systemd/tech-demo-config-helper@.service systemd/tech-demo-client@.service; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            error "Required file not found: ${file}"
            exit 1
        fi
        verbose "✓ Found: ${file}"
    done
    
    verbose "Checking current working directory: $(pwd)"
    verbose "Script directory: ${SCRIPT_DIR}"
    
    log "Prerequisites check: PASS"
}

backup_existing_files() {
    step "Backing up existing files"
    
    verbose "Creating backup directory: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    
    verbose "Checking for existing files to backup..."
    local backup_count=0
    for file in "${INSTALLED_FILES[@]}"; do
        if [[ -f "${file}" ]]; then
            verbose "Backing up existing file: ${file}"
            cp "${file}" "${BACKUP_DIR}/" 2>/dev/null || true
            log "Backed up: ${file}"
            ((backup_count++))
        else
            verbose "No existing file: ${file}"
        fi
    done
    
    verbose "Backing up systemd state..."
    systemctl list-unit-files | grep -E "tech-demo-config-helper|tech-demo-client" > "${BACKUP_DIR}/systemd-state.txt" 2>/dev/null || true
    
    if [[ -f "${BACKUP_DIR}/systemd-state.txt" ]]; then
        verbose "Existing systemd units found:"
        while IFS= read -r line; do
            verbose "  ${line}"
        done < "${BACKUP_DIR}/systemd-state.txt"
    else
        verbose "No existing systemd units found"
    fi
    
    log "Backup completed: ${backup_count} files backed up"
}

install_system() {
    step "Installing Tech Demo Config Helper"
    
    verbose "Installing scripts to /usr/local/bin/..."
    verbose "Copying tech-demo-config-helper.sh..."
    cp "${SCRIPT_DIR}/scripts/tech-demo-config-helper.sh" /usr/local/bin/
    verbose "Setting executable permissions on tech-demo-config-helper.sh..."
    chmod +x /usr/local/bin/tech-demo-config-helper.sh
    verbose "✓ Installed: /usr/local/bin/tech-demo-config-helper.sh"
    
    verbose "Copying tech-demo-client.sh..."
    cp "${SCRIPT_DIR}/scripts/tech-demo-client.sh" /usr/local/bin/
    verbose "Setting executable permissions on tech-demo-client.sh..."
    chmod +x /usr/local/bin/tech-demo-client.sh
    verbose "✓ Installed: /usr/local/bin/tech-demo-client.sh"
    
    verbose "Installing systemd units to /etc/systemd/system/..."
    verbose "Copying tech-demo-config-helper.socket..."
    cp "${SCRIPT_DIR}/systemd/tech-demo-config-helper.socket" /etc/systemd/system/
    verbose "✓ Installed: /etc/systemd/system/tech-demo-config-helper.socket"
    
    verbose "Copying tech-demo-config-helper@.service..."
    cp "${SCRIPT_DIR}/systemd/tech-demo-config-helper@.service" /etc/systemd/system/
    verbose "✓ Installed: /etc/systemd/system/tech-demo-config-helper@.service"
    
    verbose "Copying tech-demo-client@.service..."
    cp "${SCRIPT_DIR}/systemd/tech-demo-client@.service" /etc/systemd/system/
    verbose "✓ Installed: /etc/systemd/system/tech-demo-client@.service"
    
    verbose "Reloading systemd daemon..."
    systemctl daemon-reload
    verbose "✓ systemd daemon reloaded"
    
    verbose "Enabling tech-demo-config-helper.socket..."
    systemctl enable tech-demo-config-helper.socket
    verbose "✓ tech-demo-config-helper.socket enabled"
    
    verbose "Starting tech-demo-config-helper.socket..."
    systemctl start tech-demo-config-helper.socket
    verbose "✓ tech-demo-config-helper.socket started"
    
    verbose "Checking socket status..."
    local socket_status
    socket_status=$(systemctl is-active tech-demo-config-helper.socket)
    verbose "Socket status: ${socket_status}"
    
    if [[ -S /run/tech-demo-config-helper.sock ]]; then
        verbose "✓ Socket file created: /run/tech-demo-config-helper.sock"
        verbose "Socket permissions: $(ls -la /run/tech-demo-config-helper.sock)"
    else
        verbose "⚠ Socket file not found: /run/tech-demo-config-helper.sock"
    fi
    
    log "Installation completed successfully"
}

run_tests() {
    step "Running comprehensive tests"
    
    # Test 1: Socket is active
    verbose "TEST 1: Checking if socket is active..."
    verbose "Running: systemctl is-active tech-demo-config-helper.socket"
    local socket_status
    socket_status=$(systemctl is-active tech-demo-config-helper.socket)
    verbose "Socket status: ${socket_status}"
    if systemctl is-active --quiet tech-demo-config-helper.socket; then
        test_result "Socket Active" "PASS"
    else
        test_result "Socket Active" "FAIL"
        verbose "Socket status details:"
        systemctl status tech-demo-config-helper.socket --no-pager -l | while IFS= read -r line; do
            verbose "  ${line}"
        done
    fi
    
    # Test 2: Socket file exists
    verbose "TEST 2: Checking if socket file exists..."
    verbose "Checking for: /run/tech-demo-config-helper.sock"
    if [[ -S /run/tech-demo-config-helper.sock ]]; then
        verbose "✓ Socket file found"
        verbose "Socket file details: $(ls -la /run/tech-demo-config-helper.sock)"
        test_result "Socket File Exists" "PASS"
    else
        verbose "✗ Socket file not found"
        verbose "Contents of /run/:"
        ls -la /run/ | grep tech-demo || verbose "No tech-demo-related files in /run/"
        test_result "Socket File Exists" "FAIL"
    fi
    
    # Test 3: Start client service
    verbose "TEST 3: Starting client service..."
    verbose "Running: systemctl start tech-demo-client@demo-app.service"
    if systemctl start tech-demo-client@demo-app.service 2>/dev/null; then
        verbose "✓ Service started successfully"
        test_result "Start Client Service" "PASS"
        
        verbose "Waiting 3 seconds for service to complete..."
        sleep 3
        
        # Test 4: Service completed successfully
        verbose "TEST 4: Checking service execution status..."
        local service_status
        service_status=$(systemctl is-active tech-demo-client@demo-app.service)
        verbose "Service active status: ${service_status}"
        
        local exit_status
        exit_status=$(systemctl show -p ExecMainStatus tech-demo-client@demo-app.service --value)
        verbose "Service exit status: ${exit_status}"
        
        if systemctl is-active --quiet tech-demo-client@demo-app.service || [[ "${exit_status}" == "0" ]]; then
            verbose "✓ Service executed successfully"
            test_result "Service Execution" "PASS"
        else
            verbose "✗ Service execution failed"
            verbose "Service status details:"
            systemctl status tech-demo-client@demo-app.service --no-pager -l | while IFS= read -r line; do
                verbose "  ${line}"
            done
            test_result "Service Execution" "FAIL"
        fi
        
        # Test 5: Check service logs for expected output
        verbose "TEST 5: Checking service logs for expected output..."
        verbose "Looking for 'Configuration loaded successfully' in logs..."
        local log_output
        log_output=$(journalctl -u tech-demo-client@demo-app.service --no-pager -q)
        verbose "Service logs:"
        echo "${log_output}" | while IFS= read -r line; do
            verbose "  ${line}"
        done
        
        if echo "${log_output}" | grep -q "Configuration loaded successfully"; then
            verbose "✓ Found expected output in logs"
            test_result "Service Output" "PASS"
        else
            verbose "✗ Expected output not found in logs"
            test_result "Service Output" "FAIL"
        fi
        
        verbose "Stopping tech-demo-client@demo-app.service..."
        systemctl stop tech-demo-client@demo-app.service 2>/dev/null || true
        verbose "✓ Service stopped"
    else
        verbose "✗ Failed to start service"
        verbose "Service status:"
        systemctl status tech-demo-client@demo-app.service --no-pager -l | while IFS= read -r line; do
            verbose "  ${line}"
        done
        test_result "Start Client Service" "FAIL"
        test_result "Service Execution" "FAIL"
        test_result "Service Output" "FAIL"
    fi
    
    # Test 6: Multiple instances
    verbose "TEST 6: Testing multiple service instances..."
    verbose "Starting tech-demo-client@demo-api.service..."
    if systemctl start tech-demo-client@demo-api.service 2>/dev/null; then
        verbose "✓ api-service instance started"
        verbose "Waiting 2 seconds for completion..."
        sleep 2
        
        verbose "Checking logs for api-service..."
        local api_logs
        api_logs=$(journalctl -u tech-demo-client@demo-api.service --no-pager -q)
        verbose "api-service logs:"
        echo "${api_logs}" | while IFS= read -r line; do
            verbose "  ${line}"
        done
        
        if echo "${api_logs}" | grep -q "demo-api"; then
            verbose "✓ Found demo-api in logs"
            test_result "Multiple Instances" "PASS"
        else
            verbose "✗ demo-api not found in logs"
            test_result "Multiple Instances" "FAIL"
        fi
        
        verbose "Stopping api-service..."
        systemctl stop tech-demo-client@demo-api.service 2>/dev/null || true
    else
        verbose "✗ Failed to start demo-api"
        test_result "Multiple Instances" "FAIL"
    fi
    
    # Test 7: Socket handles concurrent connections
    verbose "TEST 7: Testing concurrent connections..."
    verbose "Starting multiple services simultaneously..."
    verbose "Starting: tech-demo-client@demo-app.service tech-demo-client@demo-mobile.service"
    systemctl start tech-demo-client@demo-app.service tech-demo-client@demo-mobile.service 2>/dev/null || true
    
    verbose "Waiting 3 seconds for both services to complete..."
    sleep 3
    
    local concurrent_success=0
    verbose "Checking demo-app logs..."
    local webapp_logs
    webapp_logs=$(journalctl -u tech-demo-client@demo-app.service --no-pager -q)
    if echo "${webapp_logs}" | grep -q "demo-app"; then
        verbose "✓ demo-app service completed successfully"
        ((concurrent_success++))
    else
        verbose "✗ demo-app service failed"
    fi
    
    verbose "Checking demo-mobile logs..."
    local mobile_logs
    mobile_logs=$(journalctl -u tech-demo-client@demo-mobile.service --no-pager -q)
    if echo "${mobile_logs}" | grep -q "demo-mobile"; then
        verbose "✓ demo-mobile service completed successfully"
        ((concurrent_success++))
    else
        verbose "✗ demo-mobile service failed"
    fi
    
    verbose "Concurrent success count: ${concurrent_success}/2"
    if [[ ${concurrent_success} -eq 2 ]]; then
        verbose "✓ Both concurrent services succeeded"
        test_result "Concurrent Connections" "PASS"
    else
        verbose "✗ Concurrent services failed (${concurrent_success}/2 succeeded)"
        test_result "Concurrent Connections" "FAIL"
    fi
    
    verbose "Cleaning up test services..."
    systemctl stop tech-demo-client@demo-app.service tech-demo-client@demo-mobile.service 2>/dev/null || true
    verbose "✓ Test services stopped"
}

cleanup_installation() {
    step "Cleaning up installation"
    
    verbose "Stopping and disabling services..."
    verbose "Stopping tech-demo-config-helper.socket..."
    systemctl stop tech-demo-config-helper.socket 2>/dev/null || true
    verbose "Disabling tech-demo-config-helper.socket..."
    systemctl disable tech-demo-config-helper.socket 2>/dev/null || true
    verbose "✓ Socket service stopped and disabled"
    
    verbose "Stopping any running client services..."
    for service in demo-app demo-api demo-mobile; do
        verbose "Stopping tech-demo-client@${service}.service..."
        systemctl stop "tech-demo-client@${service}.service" 2>/dev/null || true
    done
    verbose "✓ Client services stopped"
    
    verbose "Removing installed files..."
    for file in "${INSTALLED_FILES[@]}"; do
        if [[ -f "${file}" ]]; then
            verbose "Removing: ${file}"
            rm -f "${file}"
            log "Removed: ${file}"
        else
            verbose "File not found (already removed): ${file}"
        fi
    done
    
    verbose "Removing installed directories..."
    for dir in "${INSTALLED_DIRS[@]}"; do
        if [[ -d "${dir}" ]]; then
            verbose "Removing directory: ${dir}"
            rmdir "${dir}" 2>/dev/null || true
            log "Removed directory: ${dir}"
        fi
    done
    
    verbose "Checking for socket file cleanup..."
    if [[ -S /run/tech-demo-config-helper.sock ]]; then
        verbose "Socket file still exists: /run/tech-demo-config-helper.sock"
    else
        verbose "✓ Socket file cleaned up"
    fi
    
    verbose "Reloading systemd daemon..."
    systemctl daemon-reload
    verbose "Resetting failed units..."
    systemctl reset-failed 2>/dev/null || true
    verbose "✓ systemd state reset"
    
    log "Cleanup completed successfully"
}

restore_backup() {
    step "Restoring backup files"
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        verbose "Backup directory found: ${BACKUP_DIR}"
        verbose "Restoring backed up files..."
        
        local restore_count=0
        for file in "${BACKUP_DIR}"/*; do
            if [[ -f "${file}" && "${file}" != *"systemd-state.txt" ]]; then
                local basename_file
                basename_file="$(basename "${file}")"
                verbose "Processing backup file: ${basename_file}"
                
                # Restore to appropriate location
                for installed_file in "${INSTALLED_FILES[@]}"; do
                    if [[ "$(basename "${installed_file}")" == "${basename_file}" ]]; then
                        verbose "Restoring ${file} to ${installed_file}"
                        cp "${file}" "${installed_file}"
                        log "Restored: ${installed_file}"
                        ((restore_count++))
                        break
                    fi
                done
            fi
        done
        
        verbose "Restored ${restore_count} files from backup"
        
        verbose "Cleaning up backup directory..."
        rm -rf "${BACKUP_DIR}"
        verbose "✓ Backup directory removed"
    else
        verbose "No backup directory found - nothing to restore"
    fi
    
    log "Backup restoration completed"
}

print_summary() {
    log "=========================================="
    log "E2E Test Summary"
    log "=========================================="
    log "Tests Passed: ${TESTS_PASSED}"
    log "Tests Failed: ${TESTS_FAILED}"
    log "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        log ""
        log "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log "  - ${test}"
        done
        log ""
        log "Check logs for details: ${TEST_LOG}"
        return 1
    else
        log ""
        log "All tests passed! ✓"
        return 0
    fi
}

main() {
    echo "=========================================="
    echo "Tech Demo Config Helper End-to-End Test Suite"
    echo "=========================================="
    echo "Started at: $(date)"
    echo "Log file: ${TEST_LOG}"
    echo "Script directory: ${SCRIPT_DIR}"
    echo "Backup directory: ${BACKUP_DIR}"
    echo ""
    
    # Initialize log
    echo "Tech Demo Config Helper E2E Test - $(date)" > "${TEST_LOG}"
    echo "Test execution started by: $(whoami)" >> "${TEST_LOG}"
    echo "Working directory: $(pwd)" >> "${TEST_LOG}"
    echo "" >> "${TEST_LOG}"
    
    log "Starting Tech Demo Config Helper E2E Test"
    
    check_prerequisites
    backup_existing_files
    
    # Trap to ensure cleanup happens
    trap 'verbose "Trap triggered - performing cleanup"; cleanup_installation; restore_backup' EXIT
    
    install_system
    run_tests
    
    # Print summary and exit with appropriate code
    if print_summary; then
        log "E2E Test completed successfully"
        echo ""
        echo "=========================================="
        echo "✓ ALL TESTS PASSED"
        echo "=========================================="
        exit 0
    else
        error "E2E Test failed"
        echo ""
        echo "=========================================="
        echo "✗ SOME TESTS FAILED"
        echo "=========================================="
        echo "Check the log file for details: ${TEST_LOG}"
        exit 1
    fi
}

main "$@"