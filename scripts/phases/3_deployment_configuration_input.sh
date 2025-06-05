#!/bin/bash
# Phase 3: Deployment Configuration Input

ENV_UTILS_PATH="./scripts/implementation/env_utils.sh"
if [ ! -f "$ENV_UTILS_PATH" ]; then
    echo "ERROR: Environment utilities script not found at $ENV_UTILS_PATH" >&2
    exit 1
fi
source "$ENV_UTILS_PATH"

echo "Phase 3: Configuring Deployment Options for .env file..."
echo "-----------------------------------------------------------"

# Ensure .env file exists
if ! ensure_env_file; then
    echo "Failed to ensure .env file exists. Please run Phase 1 script first or check $ENV_TEMPLATE_PATH." >&2
    exit 1
fi
echo "You will be prompted for values. Press Enter to keep the current value if displayed."

# Helper function for general interactive input
prompt_for_env_update() {
    local key_name="$1"
    local prompt_message="$2"
    local default_from_template="$3"
    local current_value
    current_value=$(get_env_value "$key_name" "$default_from_template")
    local new_value

    echo ""
    echo "$prompt_message"
    echo "Current value for $key_name: \"$current_value\""
    read -r -p "Enter new value (or press Enter to keep current): " new_value

    if [ -n "$new_value" ]; then
        update_env_value "$key_name" "$new_value"
        echo "INFO: $key_name updated to: \"$new_value\" in .env file."
    else
        # If user hits enter, current_value (which might be the template default if never set) is reaffirmed
        update_env_value "$key_name" "$current_value"
        echo "INFO: $key_name remains: \"$current_value\" in .env file."
    fi
}

# --- Configure Phase 3 Options ---

# CLAUDE_USER_NAME
prompt_for_env_update "CLAUDE_USER_NAME" "Enter the dedicated user name for the Claude service on the Ubuntu server:" "claude-user"

# DEPLOYMENT_MODE
current_deploy_mode=$(get_env_value "DEPLOYMENT_MODE" "production")
while true; do
    echo ""
    echo "Select the deployment mode. Options: dev, staging, production."
    echo "Current value for DEPLOYMENT_MODE: \"$current_deploy_mode\""
    read -r -p "Enter new mode (dev/staging/production, or Enter to keep current): " new_deploy_mode

    if [ -z "$new_deploy_mode" ]; then
        # User pressed Enter, keep current_deploy_mode (which is already set or defaulted)
        update_env_value "DEPLOYMENT_MODE" "$current_deploy_mode"
        echo "INFO: DEPLOYMENT_MODE remains: \"$current_deploy_mode\" in .env file."
        break
    elif [[ "$new_deploy_mode" == "dev" || "$new_deploy_mode" == "staging" || "$new_deploy_mode" == "production" ]]; then
        update_env_value "DEPLOYMENT_MODE" "$new_deploy_mode"
        echo "INFO: DEPLOYMENT_MODE updated to: \"$new_deploy_mode\" in .env file."
        break
    else
        echo "Invalid input. Please enter 'dev', 'staging', or 'production'."
    fi
done

# ENABLE_MCP_SERVER
current_mcp_status_str=$(get_env_value "ENABLE_MCP_SERVER" "true")
while true; do
    echo ""
    echo "Enable MCP (Model Context Protocol) Server deployment? (Y/n)"
    echo "Current setting for ENABLE_MCP_SERVER: \"$current_mcp_status_str\""
    read -r -p "Enable MCP Server? (Y/n, or Enter to keep current): " mcp_response

    new_mcp_status_str=""
    if [ -z "$mcp_response" ]; then # User pressed Enter
        new_mcp_status_str=$current_mcp_status_str
    elif [[ "$mcp_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        new_mcp_status_str="true"
    elif [[ "$mcp_response" =~ ^([nN][oO]|[nN])$ ]]; then
        new_mcp_status_str="false"
    else
        echo "Invalid input. Please enter 'Y' or 'n'."
        continue
    fi

    update_env_value "ENABLE_MCP_SERVER" "$new_mcp_status_str"
    echo "INFO: ENABLE_MCP_SERVER updated to: \"$new_mcp_status_str\" in .env file."
    break
done

echo ""
echo "-----------------------------------------------------------"
echo "Phase 3 deployment configuration complete. Values saved to .env."
echo "Please review the .env file to ensure all settings are correct."
echo "Next, run './scripts/4_execute_deployment_template.sh' to prepare and review the deployment command."
echo "-----------------------------------------------------------"
