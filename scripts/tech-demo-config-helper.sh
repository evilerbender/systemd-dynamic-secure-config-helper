#!/usr/bin/env bash
#
# Tech Demo Config Helper - Socket Version
# Purpose: Demonstrate secure configuration delivery via AF_UNIX socket with automatic client identification
# Usage: Called automatically by systemd socket activation
#
set -euo pipefail

# Extract client info from socket peer name using getpeername
# Format: "\0random/unit/tech-demo-client@instance.service/DEMO_CONFIG_instance"
get_client_info() {
    # This would need a C helper or socat to get peer name
    # For now, we'll parse from environment or use a simpler method
    # In a real implementation, you'd use getpeername(2) system call
    
    # Fallback: read any input and extract client ID
    if read -r input 2>/dev/null; then
        echo "${input}"
    else
        echo "demo-app"  # Default for testing
    fi
}

# Get configuration for a client
get_config() {
    local -r client_id="$1"
    
    case "${client_id}" in
        "demo-app")
            cat << 'EOF'
{
    "client_id": "demo-app-client-id",
    "client_secret": "demo-app-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["read", "write", "admin"]
}
EOF
            ;;
        "demo-api")
            cat << 'EOF'
{
    "client_id": "demo-api-client-id", 
    "client_secret": "demo-api-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["api", "read"]
}
EOF
            ;;
        "demo-mobile")
            cat << 'EOF'
{
    "client_id": "demo-mobile-client-id",
    "client_secret": "demo-mobile-secret-key", 
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["mobile", "read"]
}
EOF
            ;;
        "web-app")
            cat << 'EOF'
{
    "client_id": "web-app-client-id",
    "client_secret": "web-app-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["web", "read", "write"]
}
EOF
            ;;
        "api-service")
            cat << 'EOF'
{
    "client_id": "api-service-client-id",
    "client_secret": "api-service-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["api", "service", "read"]
}
EOF
            ;;
        "mobile-app")
            cat << 'EOF'
{
    "client_id": "mobile-app-client-id",
    "client_secret": "mobile-app-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["mobile", "app", "read"]
}
EOF
            ;;
        "batch-processor")
            cat << 'EOF'
{
    "client_id": "batch-processor-client-id",
    "client_secret": "batch-processor-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["batch", "processing", "admin"]
}
EOF
            ;;
        "monitoring")
            cat << 'EOF'
{
    "client_id": "monitoring-client-id",
    "client_secret": "monitoring-secret-key",
    "endpoint": "https://auth.demo.example.com/oauth2/token",
    "scopes": ["monitoring", "metrics", "read"]
}
EOF
            ;;
        *)
            cat << EOF
{
    "error": "unknown_client",
    "message": "Unknown client ID: ${client_id}"
}
EOF
            ;;
    esac
}

# Main execution
main() {
    # Get client info from socket connection
    client_id=$(get_client_info)
    
    # Return configuration
    get_config "${client_id}"
}

main "$@"