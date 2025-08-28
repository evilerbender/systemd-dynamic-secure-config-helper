# systemd Dynamic Secure Config Helper - Directory Structure

```
systemd-dynamic-secure-config-helper/
├── README.md                           # Main documentation
├── STRUCTURE.md                        # This file - directory overview
├── install.sh                          # Installation script
├── test.sh                            # Test script
├── e2e-test.sh                        # End-to-end test script
│
├── systemd/                           # systemd unit files
│   ├── tech-demo-config-helper.socket      # Socket unit (creates AF_UNIX socket)
│   ├── tech-demo-config-helper@.service    # Templated helper service unit
│   ├── tech-demo-client@.service           # Example consumer service template
│   └── tech-demo-client@.service.d/         # Drop-in configuration directory
│       └── dependencies.conf          # Automatic socket dependencies
│
├── scripts/                           # Executable scripts
│   ├── tech-demo-config-helper.sh          # Socket-based helper script
│   └── tech-demo-client.sh                 # Example tech demo client script
│
└── examples/                          # Example configurations
    └── clients.json                   # Sample configuration file
```

## File Purposes

### Core System Files

- **`systemd/tech-demo-config-helper.socket`**
  - Creates secure AF_UNIX socket at `/run/tech-demo-config-helper.sock`
  - Socket activation with Accept=yes for concurrent secure connections
  - Permissions: 0666 (systemd provides kernel-level access control)

- **`systemd/tech-demo-config-helper@.service`**
  - Templated helper service for handling individual secure connections
  - Uses StandardInput=socket and StandardOutput=socket for isolation
  - Automatic client identification via socket peer name (process isolation)

- **`scripts/tech-demo-config-helper.sh`**
  - Secure socket-based implementation with automatic client identification
  - Supports multiple secure backends: Vault, HSM, AWS Secrets Manager
  - Designed for enterprise security requirements and compliance

- **`systemd/tech-demo-client@.service.d/dependencies.conf`**
  - Drop-in configuration for automatic secure socket dependencies
  - Eliminates security policy from application service files
  - Provides clean separation of security concerns from business logic

### Example/Template Files

- **`systemd/tech-demo-client@.service`**
  - Hardened template service with advanced systemd security features
  - Uses LoadCredential with secure AF_UNIX socket
  - Demonstrates process isolation and security hardening

- **`scripts/tech-demo-client.sh`**
  - Example secure client with proper credential handling
  - Secure JSON parsing with validation and error handling
  - Demonstrates secure coding practices and credential cleanup

- **`examples/clients.json`**
  - Sample secure configuration data structure
  - Multiple secure client types and use cases
  - Enterprise-grade configuration patterns

### Utility Files

- **`install.sh`**
  - Automated installation for Linux systems
  - Copies files to system locations
  - Enables and starts services

- **`test.sh`**
  - Verification script
  - Tests FIFO communication
  - Tests systemd service integration

## Installation Locations

When installed, files are copied to:

```
/etc/systemd/system/
├── tech-demo-config-helper.socket
├── tech-demo-config-helper@.service
├── tech-demo-client@.service
└── tech-demo-client@.service.d/
    └── dependencies.conf

/usr/local/bin/
├── tech-demo-config-helper.sh
└── tech-demo-client.sh

/run/
└── tech-demo-config-helper.sock         # AF_UNIX socket created by systemd
```

## Secure Usage Flow

1. **Consumer service starts** with `LoadCredential=SECURE_CONFIG_id:/run/tech-demo-config-helper.sock`
2. **systemd establishes secure socket connection** (triggers socket activation)
3. **Helper service starts in isolated environment** with socket as stdin/stdout
4. **Helper identifies client securely** via socket peer name (kernel-level identification)
5. **Helper retrieves secure config** from enterprise backend (Vault/HSM/AWS)
6. **Helper delivers encrypted config** to socket (stdout) with validation
7. **systemd provides secure config** to consumer in isolated `$CREDENTIALS_DIRECTORY`
8. **Consumer service accesses config** from secure credential file with proper cleanup

## Security Customization Points

- **Secure Backends**: Integrate with enterprise secret management (Vault, HSM, AWS KMS)
- **Client Authentication**: Implement certificate-based or token-based client authentication
- **Access Control**: Add fine-grained authorization policies and audit logging
- **Encryption**: Implement end-to-end encryption for sensitive configuration data
- **Security Hardening**: Apply additional systemd security features and sandboxing
- **Compliance**: Add audit trails, compliance reporting, and security monitoring
- **Credential Rotation**: Implement automatic credential rotation and lifecycle management
- **Multi-Tier Security**: Deploy across security zones with appropriate network isolation
