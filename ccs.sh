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
PERSONAL_JSON="personal.txt"
API_JSON="api.txt"
KEYCHAIN_SERVICE="Claude Code"

echo -e "${BLUE}=== Claude Code Authentication Switcher (macOS) ===${NC}"
echo

# Function to check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script is designed for macOS only${NC}"
        echo -e "The script uses macOS Keychain to manage Claude Code credentials."
        exit 1
    fi
}

# Function to extract credentials from keychain with detailed error reporting
get_keychain_credentials() {
    echo -e "${BLUE}Debug: Attempting to extract credentials...${NC}"
    echo -e "Debug: User: $USER"
    echo -e "Debug: Service: $KEYCHAIN_SERVICE"
    echo -e "Debug: Command: security find-generic-password -a \"$USER\" -w -s \"$KEYCHAIN_SERVICE\""
    echo
    
    # Try the command and capture both stdout and stderr
    local creds
    local error_output
    
    error_output=$(security find-generic-password -a "$USER" -w -s "$KEYCHAIN_SERVICE" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        creds="$error_output"
        echo -e "${GREEN}✓ Successfully extracted credentials${NC}"
        echo -e "Debug: Credential length: ${#creds} characters"
        echo "$creds"
    else
        echo -e "${RED}✗ Failed to extract credentials${NC}"
        echo -e "${RED}Exit code: $exit_code${NC}"
        echo -e "${RED}Error output: $error_output${NC}"
        echo
        echo -e "${YELLOW}Troubleshooting steps:${NC}"
        echo -e "1. Make sure Claude Code is installed and you've signed in at least once"
        echo -e "2. Try running this command manually to see the full error:"
        echo -e "   security find-generic-password -a \"$USER\" -w -s \"$KEYCHAIN_SERVICE\""
        echo -e "3. Check if Claude Code uses a different service name by running:"
        echo -e "   security dump-keychain | grep -i claude"
        return 1
    fi
}

# Function to set keychain credentials
set_keychain_credentials() {
    local creds="$1"
    
    echo -e "${BLUE}Debug: Setting credentials in keychain...${NC}"
    echo -e "Debug: Credential length: ${#creds} characters"
    
    # Delete existing entry if it exists
    echo -e "Debug: Deleting existing entry (if any)..."
    local delete_output
    delete_output=$(security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" 2>&1)
    local delete_exit_code=$?
    
    if [ $delete_exit_code -eq 0 ]; then
        echo -e "Debug: Existing entry deleted successfully"
    else
        echo -e "Debug: No existing entry to delete (or delete failed): $delete_output"
    fi
    
    # Add new credentials
    echo -e "Debug: Adding new credentials..."
    local add_output
    add_output=$(security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w "$creds" 2>&1)
    local add_exit_code=$?
    
    if [ $add_exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully stored credentials in keychain${NC}"
    else
        echo -e "${RED}✗ Failed to store credentials in keychain${NC}"
        echo -e "${RED}Exit code: $add_exit_code${NC}"
        echo -e "${RED}Error output: $add_output${NC}"
        return 1
    fi
}

# Function to save credentials to file
save_credentials() {
    local creds="$1"
    local output_file="$2"
    
    echo -e "${BLUE}Debug: Saving credentials to $output_file...${NC}"
    echo -e "Debug: Credential length: ${#creds} characters"
    
    # Save exactly what we extracted - no modifications
    if echo "$creds" > "$output_file"; then
        echo -e "Debug: File write successful"
    else
        echo -e "${RED}Error: Failed to write to $output_file${NC}"
        return 1
    fi
    
    # Set permissions to 600
    if chmod 600 "$output_file"; then
        echo -e "Debug: Permissions set to 600"
    else
        echo -e "${RED}Error: Failed to set permissions on $output_file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Credentials saved to $output_file${NC}"
    echo -e "Debug: File size: $(wc -c < "$output_file" | tr -d ' ') bytes"
}

# Function to restore credentials from file
restore_credentials() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: $input_file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Debug: Restoring credentials from $input_file...${NC}"
    echo -e "Debug: File size: $(wc -c < "$input_file" | tr -d ' ') bytes"
    
    # Read the file content exactly as saved
    local creds
    creds=$(cat "$input_file") || {
        echo -e "${RED}Error: Could not read $input_file${NC}"
        return 1
    }
    
    echo -e "Debug: Read ${#creds} characters from file"
    
    # Store exactly what was saved back to keychain
    set_keychain_credentials "$creds" || return 1
    
    echo -e "${GREEN}✓ Credentials restored from $input_file${NC}"
}

# Function to setup both authentications
setup_authentications() {
    echo -e "${YELLOW}=== Setup Process ===${NC}"
    echo
    
    # Step 1: Backup personal auth
    echo -e "${YELLOW}Step 1: Backing up personal Claude plan authentication${NC}"
    echo
    echo -e "Please make sure that you are signed in with your PERSONAL Claude plan and then press Enter."
    read -r
    
    echo -e "${BLUE}Extracting personal credentials from macOS Keychain...${NC}"
    
    local personal_creds
    personal_creds=$(get_keychain_credentials) || {
        echo -e "${RED}Failed to extract personal credentials. Aborting setup.${NC}"
        exit 1
    }
    
    # Save personal credentials exactly as extracted
    save_credentials "$personal_creds" "$PERSONAL_JSON" || {
        echo -e "${RED}Failed to save personal credentials. Aborting setup.${NC}"
        exit 1
    }
    
    echo
    
    # Step 2: Switch to API billing
    echo -e "${YELLOW}Step 2: Setting up API billing authentication${NC}"
    echo
    echo -e "${BLUE}Now you need to switch to API billing:${NC}"
    echo -e "1. Run: ${YELLOW}claude${NC} (or open Claude Code if not already running)"
    echo -e "2. Type: ${YELLOW}/logout${NC} to sign out"
    echo -e "3. Sign back in using your API billing account"
    echo -e "4. Once you're signed in with API billing, press Enter here"
    echo
    read -r
    
    echo -e "${BLUE}Extracting API billing credentials from macOS Keychain...${NC}"
    
    local api_creds
    api_creds=$(get_keychain_credentials) || {
        echo -e "${RED}Failed to extract API credentials. Personal auth was saved, but API setup incomplete.${NC}"
        exit 1
    }
    
    # Save API credentials exactly as extracted
    save_credentials "$api_creds" "$API_JSON" || {
        echo -e "${RED}Failed to save API credentials. Personal auth was saved, but API setup incomplete.${NC}"
        exit 1
    }
    
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
    
    # Restore personal credentials
    restore_credentials "$PERSONAL_JSON" || exit 1
    
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
    
    # Restore API credentials
    restore_credentials "$API_JSON" || exit 1
    
    echo -e "${GREEN}✓ Switched to API billing authentication${NC}"
    echo -e "${YELLOW}Note: You may need to restart Claude Code for changes to take effect${NC}"
}

# Function to analyze what type of credentials we have
analyze_credentials() {
    local creds="$1"
    
    # Try to parse as JSON first
    if echo "$creds" | jq '.' > /dev/null 2>&1; then
        echo -e "  Format: JSON"
        
        # Extract email if available
        if echo "$creds" | jq -e '.emailAddress' > /dev/null 2>&1; then
            local email
            email=$(echo "$creds" | jq -r '.emailAddress' 2>/dev/null)
            echo -e "  Email: $email"
        fi
        
        # Try to determine auth type by checking organization info
        if echo "$creds" | jq -e '.organizationUuid' > /dev/null 2>&1; then
            local org_uuid
            org_uuid=$(echo "$creds" | jq -r '.organizationUuid' 2>/dev/null)
            if [ "$org_uuid" != "null" ] && [ -n "$org_uuid" ]; then
                echo -e "  Type: API billing (has organization)"
            else
                echo -e "  Type: Personal plan"
            fi
        fi
    else
        # It's likely a plain string (API key)
        echo -e "  Format: String"
        local masked_key="${creds:0:8}...${creds: -4}"
        echo -e "  Value: $masked_key"
        echo -e "  Type: API billing"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}=== Current Status ===${NC}"
    
    # Check keychain credentials
    echo -e "Checking current keychain credentials..."
    if get_keychain_credentials > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Claude Code credentials found in keychain${NC}"
        
        local creds
        creds=$(get_keychain_credentials 2>/dev/null)
        analyze_credentials "$creds"
    else
        echo -e "${RED}✗ No Claude Code credentials in keychain${NC}"
    fi
    
    echo
    
    if [ -f "$PERSONAL_JSON" ]; then
        echo -e "${GREEN}✓ Personal auth backup: $PERSONAL_JSON${NC}"
        echo -e "  Permissions: $(stat -f "%A" "$PERSONAL_JSON" 2>/dev/null)"
        echo -e "  Size: $(wc -c < "$PERSONAL_JSON" | tr -d ' ') bytes"
    else
        echo -e "${RED}✗ Personal auth backup: Not found${NC}"
    fi
    
    if [ -f "$API_JSON" ]; then
        echo -e "${GREEN}✓ API billing auth backup: $API_JSON${NC}"
        echo -e "  Permissions: $(stat -f "%A" "$API_JSON" 2>/dev/null)"
        echo -e "  Size: $(wc -c < "$API_JSON" | tr -d ' ') bytes"
    else
        echo -e "${RED}✗ API billing auth backup: Not found${NC}"
    fi
}

# Function to check dependencies
check_dependencies() {
    echo -e "${BLUE}Debug: Checking dependencies...${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}"
        echo -e "Install with: brew install jq"
        exit 1
    else
        echo -e "Debug: jq found at $(which jq)"
    fi
    
    if ! command -v security &> /dev/null; then
        echo -e "${RED}Error: security command not found${NC}"
        echo -e "This script requires macOS security command"
        exit 1
    else
        echo -e "Debug: security found at $(which security)"
    fi
    
    echo -e "${GREEN}✓ All dependencies found${NC}"
    echo
}

# Function to test keychain access (for troubleshooting)
test_keychain() {
    echo -e "${BLUE}=== Keychain Test ===${NC}"
    echo -e "Testing keychain access..."
    echo
    
    echo -e "1. Searching for any Claude-related entries:"
    security dump-keychain | grep -i claude || echo -e "  No Claude entries found in default keychain"
    echo
    
    echo -e "2. Testing specific service lookup:"
    security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" 2>&1 || true
    echo
    
    echo -e "3. Current user: $USER"
    echo -e "4. Service name: '$KEYCHAIN_SERVICE'"
    echo -e "5. Trying alternative service names..."
    
    # Try some alternative service names
    local alt_services=("Claude Code-credentials" "claude-code" "anthropic-claude" "Claude")
    for service in "${alt_services[@]}"; do
        echo -e "   Trying: '$service'"
        if security find-generic-password -a "$USER" -s "$service" > /dev/null 2>&1; then
            echo -e "   ${GREEN}✓ Found credentials for '$service'${NC}"
        else
            echo -e "   ✗ No credentials for '$service'"
        fi
    done
}

# Main menu
show_menu() {
    echo
    echo -e "${BLUE}Choose an option:${NC}"
    echo -e "1. Setup (backup personal auth + setup API billing auth)"
    echo -e "2. Switch to personal authentication"
    echo -e "3. Switch to API billing authentication"
    echo -e "4. Show status"
    echo -e "5. Test keychain access (troubleshooting)"
    echo -e "6. Exit"
    echo
}

# Main execution
check_macos
check_dependencies

if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Enter your choice (1-6): " choice
        
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
                test_keychain
                ;;
            6)
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
        "test")
            test_keychain
            ;;
        *)
            echo -e "Usage: $0 [setup|personal|api|status|test]"
            echo -e "  setup    - Setup both personal and API billing auth"
            echo -e "  personal - Switch to personal authentication"
            echo -e "  api      - Switch to API billing authentication"
            echo -e "  status   - Show current status"
            echo -e "  test     - Test keychain access (troubleshooting)"
            echo -e "  (no args) - Interactive mode"
            exit 1
            ;;
    esac
fi