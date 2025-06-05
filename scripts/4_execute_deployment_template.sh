#!/bin/bash
# Phase 4: Running the Deployment (Template)

echo "Phase 4: Running the Deployment - Execution Template"
echo "---------------------------------------------------------"
echo "This script provides a template for executing the main deployment script."
echo "Edit the placeholder values below before running."

# --- BEGIN CONFIGURABLE VALUES ---

# Required:
TARGET_SERVER_IP="YOUR_SERVER_IP_HERE"                 # E.g., "192.168.1.100" or GCloud IP
GITHUB_PAT="YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE"    # Your GitHub PAT
SSH_PUBLIC_KEY_PATH="/path/to/your/ssh_public_key.pub" # E.g., "~/.ssh/id_rsa.pub"

# Optional:
CLAUDE_USER_NAME="claude-user" # Default is "claude-user"
DEPLOYMENT_MODE="production"   # Options: "dev", "staging", "production". Default is "production"
ENABLE_MCP_SERVER=true         # Set to false to use the --no-mcp flag

# --- END CONFIGURABLE VALUES ---

errors_found=false

# Check 1: Existence and executability of the main deployment script
MAIN_DEPLOY_SCRIPT="./scripts/src/deploy_claude_infrastructure.sh"
echo -n "Checking for main deployment script ($MAIN_DEPLOY_SCRIPT)... "
if [ ! -f "$MAIN_DEPLOY_SCRIPT" ]; then
    echo "ERROR: Main deployment script NOT FOUND at $MAIN_DEPLOY_SCRIPT."
    echo "       This script is essential for Phase 4. It should be part of the project structure."
    errors_found=true
elif [ ! -x "$MAIN_DEPLOY_SCRIPT" ]; then
    echo "ERROR: Main deployment script at $MAIN_DEPLOY_SCRIPT is NOT EXECUTABLE."
    echo "       Please run: chmod +x $MAIN_DEPLOY_SCRIPT"
    errors_found=true
else
    echo "OK."
fi

# Check 2: Placeholders in this template script
echo -n "Checking for placeholder values in this template... "
placeholder_issues=()
if [[ "$TARGET_SERVER_IP" == "YOUR_SERVER_IP_HERE" ]]; then
    placeholder_issues+=("TARGET_SERVER_IP")
fi
if [[ "$GITHUB_PAT" == "YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE" ]]; then
    placeholder_issues+=("GITHUB_PAT")
fi
if [[ "$SSH_PUBLIC_KEY_PATH" == "/path/to/your/ssh_public_key.pub" ]]; then
    placeholder_issues+=("SSH_PUBLIC_KEY_PATH")
fi

if [ ${#placeholder_issues[@]} -gt 0 ]; then
    echo "WARNING!"
    echo "  The following placeholder values in THIS script (4_execute_deployment_template.sh) still need to be edited:"
    for issue in "${placeholder_issues[@]}"; do
        echo "    - $issue"
    done
    errors_found=true # Treat as an error preventing preview of a valid command
else
    echo "OK (placeholders seem to be updated)."
fi

if $errors_found; then
    echo "---------------------------------------------------------"
    echo "❌ Please address the errors above before proceeding."
    echo "---------------------------------------------------------"
    exit 1
fi

# Construct the command
CMD="$MAIN_DEPLOY_SCRIPT"
CMD+=" --ip \"$TARGET_SERVER_IP\""
CMD+=" --token \"$GITHUB_PAT\""
CMD+=" --ssh-key \"$SSH_PUBLIC_KEY_PATH\""

if [ "$CLAUDE_USER_NAME" != "claude-user" ]; then
    CMD+=" --user \"$CLAUDE_USER_NAME\""
fi

if [ "$DEPLOYMENT_MODE" != "production" ]; then
    CMD+=" --mode \"$DEPLOYMENT_MODE\""
fi

if [ "$ENABLE_MCP_SERVER" = false ]; then
    CMD+=" --no-mcp"
fi

echo "
Preview of the command to be executed:"
echo "---------------------------------------------------------"
echo "$CMD"
echo "---------------------------------------------------------"

echo "
To execute, copy the command above and run it directly in your terminal from the project root directory."
echo "Alternatively, you can uncomment and run the 'eval' line below, but ensure this script is in the project root."
echo "# eval \"$CMD\""
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/4_execute_deployment_template.sh
