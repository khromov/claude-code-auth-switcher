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
CREDENTIAL_DIR="$HOME/.claude-code-auth-switcher"
PERSONAL_JSON="$CREDENTIAL_DIR/personal.txt"
API_JSON="$CREDENTIAL_DIR/api.txt"
KEYCHAIN_SERVICE_PERSONAL="Claude Code-credentials"
KEYCHAIN_SERVICE_API="Claude Code"

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

# Function to ensure credential directory exists and is secure
setup_credential_directory() {
    if [ ! -d "$CREDENTIAL_DIR" ]; then
        echo -e "${BLUE}Creating credential directory: $CREDENTIAL_DIR${NC}"
        if mkdir -p "$CREDENTIAL_DIR"; then
            echo -e "${GREEN}✓ Created credential directory${NC}"
        else
            echo -e "${RED}✗ Failed to create credential directory${NC}"
            exit 1
        fi
    fi
    
    # Set secure permissions (700 = rwx------)
    if chmod 700 "$CREDENTIAL_DIR"; then
        echo -e "${GREEN}✓ Secured credential directory permissions${NC}"
    else
        echo -e "${RED}✗ Failed to set directory permissions${NC}"
        exit 1
    fi
}

# Function to extract credentials from keychain with detailed error reporting
get_keychain_credentials() {
    local creds
    local error_output
    local exit_code
    local service_name="$1"  # Accept service name as parameter
    
    # Use provided service name, or try both if none provided
    if [ -n "$service_name" ]; then
        error_output=$(security find-generic-password -a "$USER" -w -s "$service_name" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            creds="$error_output"
            echo "$creds"
            return 0
        fi
    else
        # Try "Claude Code-credentials" first (personal)
        error_output=$(security find-generic-password -a "$USER" -w -s "$KEYCHAIN_SERVICE_PERSONAL" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            creds="$error_output"
            echo "$creds"
            return 0
        fi
        
        # If not found, try "Claude Code" (API)
        error_output=$(security find-generic-password -a "$USER" -w -s "$KEYCHAIN_SERVICE_API" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            creds="$error_output"
            echo "$creds"
            return 0
        fi
    fi
    
    # If both failed, show error
    echo -e "${RED}✗ Failed to extract credentials${NC}"
    echo -e "${RED}Exit code: $exit_code${NC}"
    echo -e "${RED}Error output: $error_output${NC}"
    echo
    echo -e "${YELLOW}Troubleshooting steps:${NC}"
    echo -e "1. Make sure Claude Code is installed and you've signed in at least once"
    echo -e "2. Try running these commands manually to see the full error:"
    echo -e "   security find-generic-password -a \"$USER\" -w -s \"$KEYCHAIN_SERVICE_PERSONAL\""
    echo -e "   security find-generic-password -a \"$USER\" -w -s \"$KEYCHAIN_SERVICE_API\""
    echo -e "3. Check if Claude Code uses a different service name by running:"
    echo -e "   security dump-keychain | grep -i claude"
    return 1
}

# Function to set keychain credentials
set_keychain_credentials() {
    local creds="$1"
    local service_name="$2"  # Accept service name as parameter
    
    # Delete existing entries for both possible service names
    local delete_output
    delete_output=$(security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_PERSONAL" 2>&1 || true)
    delete_output=$(security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_API" 2>&1 || true)
    
    # Add new credentials with specified service name
    local add_output
    add_output=$(security add-generic-password -a "$USER" -s "$service_name" -w "$creds" 2>&1)
    local add_exit_code=$?
    
    if [ $add_exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully stored credentials in keychain as '$service_name'${NC}"
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
    
    # Save exactly what we extracted - no modifications
    if echo "$creds" > "$output_file"; then
        # Set permissions to 600
        if chmod 600 "$output_file"; then
            echo -e "${GREEN}✓ Credentials saved to $output_file${NC}"
        else
            echo -e "${RED}Error: Failed to set permissions on $output_file${NC}"
            return 1
        fi
    else
        echo -e "${RED}Error: Failed to write to $output_file${NC}"
        return 1
    fi
}

# Function to restore credentials from file
restore_credentials() {
    local input_file="$1"
    local service_name="$2"  # Accept service name as parameter
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: $input_file not found${NC}"
        return 1
    fi
    
    # Read the file content exactly as saved
    local creds
    creds=$(cat "$input_file") || {
        echo -e "${RED}Error: Could not read $input_file${NC}"
        return 1
    }
    
    # Store exactly what was saved back to keychain with specified service name
    set_keychain_credentials "$creds" "$service_name" || return 1
    
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
    
    echo -e "${BLUE}Extracting personal credentials...${NC}"
    
    local personal_creds
    personal_creds=$(get_keychain_credentials) || {
        echo -e "${RED}Failed to extract personal credentials. Aborting setup.${NC}"
        exit 1
    }
    
    # Save personal credentials exactly as extracted and store with personal service name
    save_credentials "$personal_creds" "$PERSONAL_JSON" || {
        echo -e "${RED}Failed to save personal credentials. Aborting setup.${NC}"
        exit 1
    }
    
    # Also store personal credentials in keychain with personal service name
    set_keychain_credentials "$personal_creds" "$KEYCHAIN_SERVICE_PERSONAL" || {
        echo -e "${RED}Failed to store personal credentials in keychain. Aborting setup.${NC}"
        exit 1
    }
    
    echo
    
    # Step 2: Switch to API billing
    echo -e "${YELLOW}Step 2: Setting up API billing authentication${NC}"
    echo
    echo -e "${BLUE}Now you need to switch to API billing:${NC}"
    echo -e "1. Type: ${YELLOW}/login${NC}, choose Anthropic Console Account and then finish setting up API billing"
    echo -e "2. MAKE SURE YOU ARE SIGNED IN WITH API BILLING then press Enter here"
    echo
    read -r
    
    echo -e "${BLUE}Extracting API billing credentials...${NC}"
    
    local api_creds
    api_creds=$(get_keychain_credentials) || {
        echo -e "${RED}Failed to extract API credentials. Personal auth was saved, but API setup incomplete.${NC}"
        exit 1
    }
    
    # Save API credentials exactly as extracted and store with API service name
    save_credentials "$api_creds" "$API_JSON" || {
        echo -e "${RED}Failed to save API credentials. Personal auth was saved, but API setup incomplete.${NC}"
        exit 1
    }
    
    # Store API credentials in keychain with API service name
    set_keychain_credentials "$api_creds" "$KEYCHAIN_SERVICE_API" || {
        echo -e "${RED}Failed to store API credentials in keychain. Personal auth was saved, but API setup incomplete.${NC}"
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
    
    # Restore personal credentials with personal service name
    restore_credentials "$PERSONAL_JSON" "$KEYCHAIN_SERVICE_PERSONAL" || exit 1
    
    echo -e "${GREEN}✓ Switched to personal Claude plan authentication${NC}"
    echo -e "${YELLOW}Note: You need to restart Claude Code for changes to take effect${NC}"
}

# Function to switch to API auth
switch_to_api() {
    if [ ! -f "$API_JSON" ]; then
        echo -e "${RED}Error: $API_JSON not found. Please run setup first.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Switching to API billing authentication...${NC}"
    
    # Restore API credentials with API service name
    restore_credentials "$API_JSON" "$KEYCHAIN_SERVICE_API" || exit 1
    
    echo -e "${GREEN}✓ Switched to API billing authentication${NC}"
    echo -e "${YELLOW}Note: You need to restart Claude Code for changes to take effect${NC}"
}

# Function to analyze what type of credentials we have
analyze_credentials() {
    local creds="$1"
    
    # Check if it looks like JSON (starts with {)
    if [[ "$creds" =~ ^\{ ]]; then
        echo -e "  Format: JSON"
        echo -e "  Type: Personal plan"
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
    if ! command -v security &> /dev/null; then
        echo -e "${RED}Error: security command not found${NC}"
        echo -e "This script requires macOS security command"
        exit 1
    fi
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
    echo -e "   Personal service ($KEYCHAIN_SERVICE_PERSONAL):"
    security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_PERSONAL" 2>&1 || true
    echo -e "   API service ($KEYCHAIN_SERVICE_API):"
    security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_API" 2>&1 || true
    echo
    
    echo -e "3. Current user: $USER"
    echo -e "4. Personal service name: '$KEYCHAIN_SERVICE_PERSONAL'"
    echo -e "5. API service name: '$KEYCHAIN_SERVICE_API'"
}

# Main menu
show_menu() {
    echo
    echo -e "${BLUE}Choose an option:${NC}"
    echo -e "1. Setup (backup personal auth + setup API billing auth)"
    echo -e "2. Switch to personal authentication"
    echo -e "3. Switch to API billing authentication"
    echo -e "4. Exit"
    echo
}

# Main execution
check_macos
check_dependencies
setup_credential_directory

if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Enter your choice (1-4): " choice
        
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
        "personal"|"p")
            switch_to_personal
            ;;
        "api"|"a")
            switch_to_api
            ;;
        *)
            echo -e "Usage: $0 [setup|personal|p|api|a]"
            echo -e "  setup      - Setup both personal and API billing auth"
            echo -e "  personal|p - Switch to personal authentication"
            echo -e "  api|a      - Switch to API billing authentication"
            echo -e "  (no args) - Interactive mode"
            exit 1
            ;;
    esac
fi