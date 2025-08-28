#!/usr/bin/env bash
#
# Tech Demo Config Helper Test Script - Socket Version
# Purpose: Test the AF_UNIX socket-based tech demo config helper functionality
# Usage: ./test.sh [client_id]
#
set -euo pipefail

CLIENT_ID="${1:-demo-app}"

echo "Testing Tech Demo Config Helper (Socket Version) with client ID: ${CLIENT_ID}"
echo "==============================================================================="

# Check if socket is active
if ! systemctl is-active --quiet tech-demo-config-helper.socket; then
    echo "ERROR: tech-demo-config-helper.socket is not active"
    echo "Run: sudo systemctl start tech-demo-config-helper.socket"
    exit 1
fi

echo "Socket status: $(systemctl is-active tech-demo-config-helper.socket)"

# Test with systemd service
echo ""
echo "Testing with systemd service..."
echo "Starting tech-demo-client@${CLIENT_ID}.service..."

# Start the service
systemctl start "tech-demo-client@${CLIENT_ID}.service" || {
    echo "ERROR: Failed to start service"
    exit 1
}

# Wait a moment for it to complete
sleep 3

# Show the logs
echo ""
echo "Service logs:"
journalctl -u "tech-demo-client@${CLIENT_ID}.service" --no-pager -n 20

# Clean up
systemctl stop "tech-demo-client@${CLIENT_ID}.service" 2>/dev/null || true

echo ""
echo "Socket-based test completed successfully!"