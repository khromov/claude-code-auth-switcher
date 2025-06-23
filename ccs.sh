#!/bin/bash

# Claude Code Authentication Switcher for macOS
# Switches between Pro/Max personal auth and API billing auth using macOS Keychain

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# File paths
PERSONAL_JSON="personal.json"
API_JSON="api.json"
KEYCHAIN_SERVICE="Claude Code-credentials"

echo -e "${BLUE}=== Claude Code Authentication Switcher (macOS) ===${NC}"
echo

# Function to check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script is designed for macOS only${NC}"
        echo "The script uses macOS Keychain to manage Claude Code credentials."
        exit 1
    fi
}

# Function to extract credentials from keychain
get_keychain_credentials() {
    local creds
    creds=$(security find-generic-password -a "$USER" -w -s "$KEYCHAIN_SERVICE" 2>/dev/null) || {
        echo -e "${RED}Error: Could not find Claude Code credentials in keychain${NC}"
        echo "Please make sure you are signed in with Claude Code first."
        return 1
    }
    echo "$creds"
}

# Function to set keychain credentials
set_keychain_credentials() {
    local creds="$1"
    
    # Delete existing entry if it exists
    security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" 2>/dev/null || true
    
    # Add new credentials
    security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w "$creds" || {
        echo -e "${RED}Error: Failed to store credentials in keychain${NC}"
        return 1
    }
}

# Function to setup both authentications
setup_authentications() {
    echo -e "${YELLOW}=== Setup Process ===${NC}"
    echo
    
    # Step 1: Backup personal auth
    echo -e "${YELLOW}Step 1: Backing up personal Claude plan authentication${NC}"
    echo
    echo "Please make sure that you are signed in with your PERSONAL Claude plan and then press Enter."
    read -r
    
    echo -e "${BLUE}Extracting personal credentials from macOS Keychain...${NC}"
    
    local personal_creds
    personal_creds=$(get_keychain_credentials) || exit 1
    
    # Save credentials to file with proper formatting
    echo "$personal_creds" | jq '.' > "$PERSONAL_JSON" || {
        # If jq fails, save as-is (might already be properly formatted)
        echo "$personal_creds" > "$PERSONAL_JSON"
    }
    
    # Set permissions to 600
    chmod 600 "$PERSONAL_JSON"
    
    echo -e "${GREEN}✓ Personal authentication saved to $PERSONAL_JSON${NC}"
    echo
    
    # Step 2: Switch to API billing
    echo -e "${YELLOW}Step 2: Setting up API billing authentication${NC}"
    echo
    echo -e "${BLUE}Now you need to switch to API billing:${NC}"
    echo "1. Run: ${YELLOW}claude${NC} (or open Claude Code if not already running)"
    echo "2. Type: ${YELLOW}/logout${NC} to sign out"
    echo "3. Sign back in using your API billing account"
    echo "4. Once you're signed in with API billing, press Enter here"
    echo
    read -r
    
    echo -e "${BLUE}Extracting API billing credentials from macOS Keychain...${NC}"
    
    local api_creds
    api_creds=$(get_keychain_credentials) || exit 1
    
    # Save API credentials to file with proper formatting
    echo "$api_creds" | jq '.' > "$API_JSON" || {
        # If jq fails, save as-is (might already be properly formatted)
        echo "$api_creds" > "$API_JSON"
    }
    
    # Set permissions to 600
    chmod 600 "$API_JSON"
    
    echo -e "${GREEN}✓ API billing authentication saved to $API_JSON${NC}"
    echo
    echo -e "${GREEN}✓ Setup complete! You can now switch between personal and API billing auth.${NC}"
}

# Function to switch to personal auth
switch_to_personal() {
    if [ ! -f "$PERSONAL_JSON" ]; then
        echo -e "${RED}Error: $PERSONAL_JSON not found. Please run setup first.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Switching to personal authentication...${NC}"
    
    # Read credentials from file
    local creds
    creds=$(cat "$PERSONAL_JSON") || {
        echo -e "${RED}Error: Could not read credentials from $PERSONAL_JSON${NC}"
        exit 1
    }
    
    # Validate JSON format
    echo "$creds" | jq '.' > /dev/null 2>&1 || {
        echo -e "${RED}Error: Invalid JSON format in $PERSONAL_JSON${NC}"
        exit 1
    }
    
    # Store in keychain
    set_keychain_credentials "$creds" || exit 1
    
    echo -e "${GREEN}✓ Switched to personal Claude plan authentication${NC}"
    echo -e "${YELLOW}Note: You may need to restart Claude Code for changes to take effect${NC}"
}

# Function to switch to API auth
switch_to_api() {
    if [ ! -f "$API_JSON" ]; then
        echo -e "${RED}Error: $API_JSON not found. Please run setup first.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Switching to API billing authentication...${NC}"
    
    # Read credentials from file
    local creds
    creds=$(cat "$API_JSON") || {
        echo -e "${RED}Error: Could not read credentials from $API_JSON${NC}"
        exit 1
    }
    
    # Validate JSON format
    echo "$creds" | jq '.' > /dev/null 2>&1 || {
        echo -e "${RED}Error: Invalid JSON format in $API_JSON${NC}"
        exit 1
    }
    
    # Store in keychain
    set_keychain_credentials "$creds" || exit 1
    
    echo -e "${GREEN}✓ Switched to API billing authentication${NC}"
    echo -e "${YELLOW}Note: You may need to restart Claude Code for changes to take effect${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}=== Current Status ===${NC}"
    
    # Check keychain credentials
    if get_keychain_credentials > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Claude Code credentials found in keychain${NC}"
        
        # Try to extract some info without exposing sensitive data
        local creds
        creds=$(get_keychain_credentials 2>/dev/null)
        if echo "$creds" | jq -e '.emailAddress' > /dev/null 2>&1; then
            local email
            email=$(echo "$creds" | jq -r '.emailAddress' 2>/dev/null)
            echo "  Current email: $email"
        fi
        
        # Try to determine auth type by checking organization info
        if echo "$creds" | jq -e '.organizationUuid' > /dev/null 2>&1; then
            local org_uuid
            org_uuid=$(echo "$creds" | jq -r '.organizationUuid' 2>/dev/null)
            if [ "$org_uuid" != "null" ] && [ -n "$org_uuid" ]; then
                echo "  Auth type: Likely API billing (has organization)"
            else
                echo "  Auth type: Likely personal plan"
            fi
        fi
    else
        echo -e "${RED}✗ No Claude Code credentials in keychain${NC}"
    fi
    
    echo
    
    if [ -f "$PERSONAL_JSON" ]; then
        echo -e "${GREEN}✓ Personal auth backup: $PERSONAL_JSON${NC}"
        echo "  Permissions: $(stat -f "%A" "$PERSONAL_JSON" 2>/dev/null)"
        
        # Show email from backup if available
        if jq -e '.emailAddress' "$PERSONAL_JSON" > /dev/null 2>&1; then
            local backup_email
            backup_email=$(jq -r '.emailAddress' "$PERSONAL_JSON" 2>/dev/null)
            echo "  Personal email: $backup_email"
        fi
    else
        echo -e "${RED}✗ Personal auth backup: Not found${NC}"
    fi
    
    if [ -f "$API_JSON" ]; then
        echo -e "${GREEN}✓ API billing auth backup: $API_JSON${NC}"
        echo "  Permissions: $(stat -f "%A" "$API_JSON" 2>/dev/null)"
        
        # Show email from API backup if available
        if jq -e '.emailAddress' "$API_JSON" > /dev/null 2>&1; then
            local api_email
            api_email=$(jq -r '.emailAddress' "$API_JSON" 2>/dev/null)
            echo "  API billing email: $api_email"
        fi
    else
        echo -e "${RED}✗ API billing auth backup: Not found${NC}"
    fi
}

# Function to check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}"
        echo "Install with: brew install jq"
        exit 1
    fi
    
    if ! command -v security &> /dev/null; then
        echo -e "${RED}Error: security command not found${NC}"
        echo "This script requires macOS security command"
        exit 1
    fi
}

# Main menu
show_menu() {
    echo
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1. Setup (backup personal auth + setup API billing auth)"
    echo "2. Switch to personal authentication"
    echo "3. Switch to API billing authentication"
    echo "4. Show status"
    echo "5. Exit"
    echo
}

# Main execution
check_macos
check_dependencies

if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Enter your choice (1-5): " choice
        
        case $choice in
            1)
                setup_authentications
                ;;
            2)
                switch_to_personal
                ;;
            3)
                switch_to_api
                ;;
            4)
                show_status
                ;;
            5)
                echo -e "${BLUE}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
        echo
    done
else
    # Command line mode
    case $1 in
        "setup")
            setup_authentications
            ;;
        "personal")
            switch_to_personal
            ;;
        "api")
            switch_to_api
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [setup|personal|api|status]"
            echo "  setup    - Setup both personal and API billing auth"
            echo "  personal - Switch to personal authentication"
            echo "  api      - Switch to API billing authentication"
            echo "  status   - Show current status"
            echo "  (no args) - Interactive mode"
            exit 1
            ;;
    esac
fi