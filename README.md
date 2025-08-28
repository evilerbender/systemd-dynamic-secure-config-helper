# systemd Dynamic Secure Config Helper

A systemd socket-activated service that provides secure configuration data to other services via systemd's `LoadCredential` mechanism using AF_UNIX sockets with strong process isolation.

## Overview

This system demonstrates advanced systemd capabilities for dynamic, runtime retrieval of sensitive configuration data while ensuring strong isolation between processes. The helper service uses AF_UNIX socket activation with automatic client identification, eliminating hardcoded credentials and providing secure, per-service configuration delivery.



## Architecture

```
┌─────────────────┐    LoadCredential    ┌──────────────────┐
│  Consumer       │◄─────────────────────┤ systemd          │
│  Service        │                      │ Credential       │
│  (Isolated)     │                      │ System           │
└─────────────────┘                      │ (Secure Delivery)│
                                         └──────────────────┘
                                                   │
                                                   │ AF_UNIX Socket
                                                   │ (Process Isolation)
                                                   ▼
┌─────────────────┐    Socket Activation  ┌──────────────────┐
│ Config Helper   │◄─────────────────────┤ systemd          │
│ Service         │                      │ Socket Manager   │
│ (Privileged)    │                      │ (Access Control) │
└─────────────────┘                      └──────────────────┘
         │
         │ Secure Lookup
         ▼
┌─────────────────┐
│ Secure Config   │
│ Backend         │
│ (Vault/HSM/etc) │
└─────────────────┘
```

## Components

### Core Files

- **`systemd/tech-demo-config-helper.socket`** - Socket unit that creates the secure AF_UNIX socket
- **`systemd/tech-demo-config-helper@.service`** - Templated service unit for handling secure connections
- **`scripts/tech-demo-config-helper.sh`** - Helper script with automatic client identification and secure config delivery
- **`systemd/tech-demo-client@.service.d/dependencies.conf`** - Drop-in for automatic dependency management

### Example Files

- **`systemd/tech-demo-client@.service`** - Example consumer service demonstrating secure config usage
- **`scripts/tech-demo-client.sh`** - Example client script showing secure credential handling
- **`examples/clients.json`** - Example secure configuration data structure

### Utilities

- **`install.sh`** - Installation script for Linux systems
- **`test.sh`** - Test script to verify functionality

## Installation

### Prerequisites

- Linux system with systemd
- Root access for installation
- Optional: AWS CLI, Vault CLI, jq (for advanced features)

### Basic Installation

```bash
# Clone or copy the files to your system
sudo ./install.sh
```

### Manual Installation

```bash
# Copy scripts
sudo cp scripts/tech-demo-config-helper.sh /usr/local/bin/
sudo cp scripts/tech-demo-client.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tech-demo-config-helper.sh
sudo chmod +x /usr/local/bin/tech-demo-client.sh

# Copy systemd units
sudo cp systemd/tech-demo-config-helper.socket /etc/systemd/system/
sudo cp systemd/tech-demo-config-helper@.service /etc/systemd/system/
sudo cp systemd/tech-demo-client@.service /etc/systemd/system/

# Install drop-in configuration
sudo mkdir -p /etc/systemd/system/tech-demo-client@.service.d/
sudo cp systemd/tech-demo-client@.service.d/dependencies.conf /etc/systemd/system/tech-demo-client@.service.d/

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable tech-demo-config-helper.socket
sudo systemctl start tech-demo-config-helper.socket
```

## Usage

### Basic Secure Service

```ini
[Unit]
Description=My Secure Application

[Service]
Type=simple
LoadCredential=SECURE_CONFIG_myapp:/run/tech-demo-config-helper.sock
ExecStart=/usr/local/bin/my-secure-application
# Additional security hardening
PrivateNetwork=false
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
```

**Note**: For custom services, create a drop-in directory:
```bash
sudo mkdir -p /etc/systemd/system/my-service.service.d/
sudo cp /etc/systemd/system/tech-demo-client@.service.d/dependencies.conf \
         /etc/systemd/system/my-service.service.d/
```

### Template Service (Multiple Secure Instances)

```ini
[Unit]
Description=Secure Config Client (instance %i)

[Service]
Type=simple
LoadCredential=SECURE_CONFIG_%i:/run/tech-demo-config-helper.sock
ExecStart=/usr/local/bin/tech-demo-client.sh %i
# Enhanced security for sensitive workloads
DynamicUser=true
PrivateTmp=true
ProtectKernelTunables=true
RestrictRealtime=true

[Install]
WantedBy=multi-user.target
```

**Note**: Dependencies are automatically managed via systemd drop-in configuration.

Start secure instances with:
```bash
sudo systemctl start tech-demo-client@database.service
sudo systemctl start tech-demo-client@payment-api.service
sudo systemctl start tech-demo-client@crypto-service.service
```

### Accessing Secure Credentials in Your Application

```bash
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ID="$1"
CONFIG_FILE="${CREDENTIALS_DIRECTORY}/SECURE_CONFIG_${CLIENT_ID}"

# Validate credential file exists and is readable
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Secure configuration not available" >&2
    exit 1
fi

# Parse secure configuration with validation
if ! CLIENT_SECRET=$(jq -r '.client_secret // empty' "${CONFIG_FILE}") || [[ -z "${CLIENT_SECRET}" ]]; then
    echo "ERROR: Invalid or missing client_secret" >&2
    exit 1
fi

ENDPOINT=$(jq -r '.endpoint' "${CONFIG_FILE}")
SCOPES=$(jq -r '.scopes | join(",")' "${CONFIG_FILE}")

# Use secure configuration with proper error handling
if ! curl -f -s -X POST "${ENDPOINT}/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$(jq -r '.client_id' "${CONFIG_FILE}")" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "scope=${SCOPES}"; then
    echo "ERROR: Authentication failed" >&2
    exit 1
fi

# Clear sensitive variables
unset CLIENT_SECRET
```

## Secure Configuration Backends

### Local Configuration (Development Only)

Hardcoded configurations in the helper script. **Use only for development and testing.**

### AWS Secrets Manager (Production)

Enterprise-grade secret management with automatic rotation:
```bash
export CONFIG_SOURCE=aws-secrets
export AWS_REGION=us-west-2
```

Store sensitive configurations with paths like:
- `secure-config/database-credentials`
- `secure-config/api-keys`
- `secure-config/encryption-keys`

### HashiCorp Vault (Enterprise)

High-security secret management with advanced access controls:
```bash
export CONFIG_SOURCE=vault
export VAULT_ADDR=https://vault.enterprise.com
export VAULT_TOKEN=your-vault-token
```

Store secrets in Vault with strict access policies:
- `secret/secure-config/payment-processor`
- `secret/secure-config/crypto-keys`
- `secret/secure-config/database-master`

### Hardware Security Module (HSM)

For maximum security requirements:
```bash
export CONFIG_SOURCE=hsm
export HSM_SLOT=0
export HSM_PIN_FILE=/etc/hsm/pin
```

### Encrypted Configuration Files

For air-gapped or offline environments:
```bash
export CONFIG_SOURCE=encrypted-file
export CONFIG_FILE=/etc/secure-config/encrypted-configs.json.gpg
export GPG_KEY_ID=your-key-id
```

## Testing

### Service Test

```bash
# Test via systemd service (socket communication is automatic)
sudo systemctl start tech-demo-client@demo-app.service
sudo journalctl -f -u tech-demo-client@demo-app.service
```

### Automated Test

```bash
./test.sh web-app
```

### Service Test

```bash
# Start example service
sudo systemctl start tech-demo-client@demo-app.service

# Check logs
sudo journalctl -f -u tech-demo-client@demo-app.service
```

## Security Features

### Strong Process Isolation
1. **Socket-Level Access Control**: systemd manages AF_UNIX socket permissions and access
2. **Automatic Client Identification**: Socket peer name identification eliminates credential leakage
3. **Per-Service Isolation**: Each service receives credentials in isolated, private directories
4. **Runtime-Only Credentials**: Sensitive data exists only during service execution
5. **Privileged Helper Separation**: Only the helper service accesses external secure backends

### Advanced systemd Security Features
6. **LoadCredential Integration**: Native systemd credential delivery mechanism
7. **Socket Activation**: On-demand, just-in-time credential provisioning
8. **Drop-in Configuration**: Clean separation of security policy from application logic
9. **Template Services**: Scalable, per-instance security boundaries
10. **Credential Directory Isolation**: Automatic cleanup and access control

## Troubleshooting

### Check Socket Status

```bash
sudo systemctl status tech-demo-config-helper.socket
```

### Check Service Logs

```bash
sudo journalctl -f -u tech-demo-config-helper.service
```

### Verify Socket

```bash
ls -la /run/tech-demo-config-helper.sock
```

### Test Connectivity

```bash
# Should show the socket listening
sudo systemctl list-sockets | grep tech-demo-config-helper
```

## Advanced Configuration

### Automatic Dependencies

The system uses systemd drop-in configuration to automatically manage dependencies. The drop-in file `/etc/systemd/system/tech-demo-client@.service.d/dependencies.conf` contains:

```ini
[Unit]
After=tech-demo-config-helper.socket
Wants=tech-demo-config-helper.socket
```

This approach:
- Keeps service files clean and focused on application logic
- Automatically applies socket dependencies to template services
- Can be copied to other services that need secure configuration
- Allows centralized dependency management

### Custom Helper Script

Replace `/usr/local/bin/tech-demo-config-helper.sh` with your own implementation that:
1. Reads client ID from stdin
2. Retrieves configuration from your preferred source
3. Outputs JSON configuration to stdout

### Environment Variables

The advanced helper script supports these environment variables:
- `DEMO_CONFIG_SOURCE`: Configuration source (local, aws-secrets, vault, file)
- `DEMO_CONFIG_FILE`: Path to configuration file (for file source)
- `AWS_REGION`: AWS region for Secrets Manager
- `VAULT_ADDR`: Vault server address
- `VAULT_TOKEN`: Vault authentication token

### Advanced systemd Security Features

Leverage systemd's advanced security capabilities:

```ini
[Service]
# Process isolation
DynamicUser=true
PrivateUsers=true
PrivateNetwork=false
PrivateTmp=true
PrivateDevices=true

# Filesystem protection
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Capability restrictions
CapabilityBoundingSet=
AmbientCapabilities=
NoNewPrivileges=true

# System call filtering
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
RestrictRealtime=true
RestrictSUIDSGID=true

# Memory protection
MemoryDenyWriteExecute=true
RestrictNamespaces=true

# Resource limits
TasksMax=10
MemoryMax=128M
CPUQuota=50%
```

### Service Customization

Modify the service unit to:
- Implement least-privilege access controls
- Add hardware security module integration
- Configure audit logging and monitoring
- Set up automatic credential rotation

## Examples

See the `examples/` directory for:
- Secure configuration data structures
- Hardened consumer service templates
- Enterprise integration patterns
- Advanced security configurations
- Multi-tier security architectures
- Compliance and audit configurations

## systemd Security Capabilities Demonstrated

This project showcases advanced systemd security features:

### Native Credential Management
- **LoadCredential**: Secure credential delivery without environment variables
- **Credential Isolation**: Per-service credential directories with automatic cleanup
- **Runtime-Only Access**: Credentials exist only during service execution

### Socket-Based Security
- **AF_UNIX Sockets**: Process-to-process communication with kernel-level access control
- **Socket Activation**: On-demand service instantiation for minimal attack surface
- **Peer Identification**: Automatic client identification via socket metadata

### Process Isolation
- **DynamicUser**: Automatic user/group creation for service isolation
- **Private Namespaces**: Filesystem, network, and process namespace isolation
- **Capability Dropping**: Minimal privilege execution with capability restrictions

### System Hardening
- **System Call Filtering**: Restrict available system calls to essential operations
- **Memory Protection**: Prevent code injection and memory corruption attacks
- **Resource Limits**: Prevent resource exhaustion and denial-of-service

### Configuration Management
- **Drop-in Directories**: Modular configuration without file modification
- **Template Services**: Scalable, per-instance security policies
- **Dependency Management**: Automatic service ordering and dependency resolution

## License

This project is provided as-is for educational and operational use.
