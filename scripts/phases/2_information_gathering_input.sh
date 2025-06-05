#!/bin/bash
# Phase 2: Information and Credentials Input

ENV_UTILS_PATH="./scripts/implementation/env_utils.sh"
if [ ! -f "$ENV_UTILS_PATH" ]; then
    echo "ERROR: Environment utilities script not found at $ENV_UTILS_PATH" >&2
    exit 1
fi
source "$ENV_UTILS_PATH"

echo "Phase 2: Gathering Information and Credentials for .env file..."
echo "--------------------------------------------------------------------"

# Ensure .env file exists, creating from template if necessary
if ! ensure_env_file; then # This function is from env_utils.sh
    echo "Failed to ensure .env file exists. Please check $ENV_TEMPLATE_PATH and permissions." >&2
    exit 1
fi
echo "You will be prompted for values. Press Enter to keep the current value if displayed."

# Helper function for interactive input
prompt_for_env_update() {
    local key_name="$1"
    local prompt_message="$2"
    local default_placeholder="$3"
    local current_value
    current_value=$(get_env_value "$key_name" "$default_placeholder") # Get current or default placeholder
    local new_value

    echo ""
    echo "$prompt_message"
    if [ "$current_value" == "$default_placeholder" ] && [ -n "$default_placeholder" ]; then
        echo "Current value for $key_name: (placeholder -> $default_placeholder)"
    else
        echo "Current value for $key_name: \"$current_value\""
    fi
    read -r -p "Enter new value (or press Enter to keep current): " new_value

    if [ -n "$new_value" ]; then
        update_env_value "$key_name" "$new_value"
        echo "INFO: $key_name updated to: \"$new_value\" in .env file."
    elif [ -n "$current_value" ]; then # If new_value is empty, keep/set current_value
        update_env_value "$key_name" "$current_value"
        echo "INFO: $key_name remains: \"$current_value\" in .env file."
    else # Should not happen if default_placeholder is used correctly, but as a fallback
        echo "INFO: No value provided and no current value for $key_name. It may remain empty or use template default."
    fi

    # Specific validation for SSH_PUBLIC_KEY_PATH
    if [ "$key_name" == "SSH_PUBLIC_KEY_PATH" ]; then
        local final_path
        final_path=$(get_env_value "$key_name")
        # Resolve tilde for path validation
        eval resolved_path="$final_path" # This handles ~ correctly for local paths
        if [ -z "$final_path" ] || [ "$final_path" == "$default_placeholder" ]; then
            echo "Warning: SSH_PUBLIC_KEY_PATH is still a placeholder or empty. This is required for deployment."
        elif [ ! -f "$resolved_path" ]; then
            echo "Warning: SSH public key file NOT FOUND at local path '$resolved_path'. Please ensure the path is correct and accessible."
        else
            echo "INFO: SSH public key file found locally at '$resolved_path'."
        fi
    fi
}

# --- Gather Phase 2 Information ---
prompt_for_env_update "TARGET_SERVER_IP" "Enter the IP address of the target Ubuntu server:" "YOUR_SERVER_IP_HERE"
prompt_for_env_update "SSH_PUBLIC_KEY_PATH" "Enter the FULL local path to your SSH public key file (e.g., ~/.ssh/id_rsa.pub):" "/path/to/your/ssh_public_key.pub"
prompt_for_env_update "GITHUB_PAT" "Enter your GitHub Personal Access Token (PAT). Needs repo, PR, and gh auth scopes:" "YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE"
prompt_for_env_update "ANTHROPIC_API_KEY" "Enter your Anthropic API Key (also set as ANTHROPIC_API_KEY secret in GitHub repo):" "YOUR_ANTHROPIC_API_KEY_HERE"

echo ""
echo "--------------------------------------------------------------------"
echo "Phase 2 information gathering complete. Values have been saved to .env."
echo "Please review the .env file to ensure all values are correct."
echo "Next, run './scripts/3_deployment_configuration_input.sh' to configure deployment options."
echo "--------------------------------------------------------------------"
