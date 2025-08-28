#!/usr/bin/env bash
#
# Tech Demo Client Script - Socket Version
# Purpose: Demonstrates secure config retrieval from AF_UNIX socket credential helper
# Usage: tech-demo-client.sh <client_id>
#
set -euo pipefail

CLIENT_ID="$1"
CONFIG_FILE="${CREDENTIALS_DIRECTORY}/DEMO_CONFIG_${CLIENT_ID}"

echo "Starting tech demo client for: ${CLIENT_ID}"
echo "Config file: ${CONFIG_FILE}"

if [[ -f "${CONFIG_FILE}" ]]; then
    echo "Configuration loaded successfully"
    echo "Configuration content:"
    cat "${CONFIG_FILE}"
    echo ""
    
    # Check if jq is available for JSON parsing
    if command -v jq >/dev/null 2>&1; then
        # Parse JSON config
        CLIENT_SECRET=$(jq -r '.client_secret' "${CONFIG_FILE}")
        ENDPOINT=$(jq -r '.endpoint' "${CONFIG_FILE}")
        SCOPES=$(jq -r '.scopes | join(",")' "${CONFIG_FILE}")
        
        echo "Parsed configuration:"
        echo "  Client ID: $(jq -r '.client_id' "${CONFIG_FILE}")"
        echo "  Endpoint: ${ENDPOINT}"
        echo "  Scopes: ${SCOPES}"
        echo "  Client Secret: [REDACTED]"
        
        # Check for errors in config
        if [[ "$(jq -r '.error // empty' "${CONFIG_FILE}")" != "" ]]; then
            echo "ERROR: Configuration contains error: $(jq -r '.message // .error' "${CONFIG_FILE}")"
            exit 1
        fi
        
        # Your application logic here
        echo ""
        echo "Tech demo client would now use these credentials to:"
        echo "1. Authenticate with demo endpoint: ${ENDPOINT}"
        echo "2. Request scopes: ${SCOPES}"
        echo "3. Use client credentials for API calls"
        
        # Simulate some work
        echo "Simulating tech demo client work..."
        sleep 2
        echo "Tech demo client completed successfully"
        
    else
        echo "WARNING: jq not available, cannot parse JSON config"
        echo "Raw config content:"
        cat "${CONFIG_FILE}"
    fi
else
    echo "ERROR: Configuration file not found: ${CONFIG_FILE}"
    echo "Available files in credentials directory:"
    ls -la "${CREDENTIALS_DIRECTORY}/" || echo "Credentials directory not accessible"
    exit 1
fi