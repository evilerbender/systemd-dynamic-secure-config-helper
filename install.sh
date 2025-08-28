#!/usr/bin/env bash
#
# Tech Demo Config Helper Installation Script - Socket Version
# Purpose: Install the AF_UNIX socket-based tech demo config helper system
# Usage: sudo ./install.sh
#
set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" >&2
   exit 1
fi

echo "Installing Tech Demo Config Helper (Socket Version)..."

# Create directories
echo "Creating directories..."
mkdir -p /usr/local/bin

# Copy scripts
echo "Installing scripts..."
cp scripts/tech-demo-config-helper.sh /usr/local/bin/
cp scripts/tech-demo-client.sh /usr/local/bin/
chmod +x /usr/local/bin/tech-demo-config-helper.sh
chmod +x /usr/local/bin/tech-demo-client.sh

# Copy systemd units
echo "Installing systemd units..."
cp systemd/tech-demo-config-helper.socket /etc/systemd/system/
cp systemd/tech-demo-config-helper@.service /etc/systemd/system/
cp systemd/tech-demo-client@.service /etc/systemd/system/

# Install drop-in configuration
echo "Installing drop-in configuration..."
mkdir -p /etc/systemd/system/tech-demo-client@.service.d/
cp systemd/tech-demo-client@.service.d/dependencies.conf /etc/systemd/system/tech-demo-client@.service.d/

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Enable and start the socket
echo "Enabling and starting tech-demo-config-helper.socket..."
systemctl enable tech-demo-config-helper.socket
systemctl start tech-demo-config-helper.socket

# Check status
echo ""
echo "Installation complete!"
echo ""
echo "Status:"
systemctl status tech-demo-config-helper.socket --no-pager -l

echo ""
echo "To test the installation:"
echo "  sudo systemctl start tech-demo-client@demo-app.service"
echo "  sudo journalctl -f -u tech-demo-client@demo-app.service"
echo ""
echo "Socket-based approach eliminates the need for manual FIFO testing."