#!/bin/bash
# Phase 4: Execute Deployment

ENV_UTILS_PATH="./scripts/implementation/env_utils.sh"
if [ ! -f "$ENV_UTILS_PATH" ]; then
    echo "ERROR: Environment utilities script not found at $ENV_UTILS_PATH" >&2
    exit 1
fi
source "$ENV_UTILS_PATH"

echo "Phase 4: Preparing and Reviewing Deployment Command..."
echo "-----------------------------------------------------------"

# Check 1: Ensure .env file exists
if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "ERROR: .env file not found!"
    echo "Please run scripts from Phase 1, 2, and 3 first to create and populate the .env file."
    echo "  1. ./scripts/1_prerequisites_check.sh"
    echo "  2. ./scripts/2_information_gathering_input.sh"
    echo "  3. ./scripts/3_deployment_configuration_input.sh"
    echo "-----------------------------------------------------------"
    exit 1
fi

# Check 2: Ensure required variables are set in .env and are not placeholders
echo "Verifying required variables in .env file..."
# Define required keys and their placeholder values from .env.template
# This helps ensure the user has actually filled them in.
if ! check_required_env_vars "$ENV_FILE_PATH" \
    "TARGET_SERVER_IP=YOUR_SERVER_IP_HERE" \
    "SSH_PUBLIC_KEY_PATH=/path/to/your/ssh_public_key.pub" \
    "GITHUB_PAT=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE" \
    "ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY_HERE"; then # This one is for workflows but good to check
    echo ""
    echo "ERROR: One or more required variables in '$ENV_FILE_PATH' are missing or still set to placeholder values." >&2
    echo "Please run './scripts/2_information_gathering_input.sh' again to fill them correctly." >&2
    echo "-----------------------------------------------------------"
    exit 1
fi
echo "Required variables in .env are present and seem to be updated from placeholders."

# Source the .env file to load variables into the current shell
# Use `set -a` to export all variables defined from now on, and `set +a` to turn it off.
# This makes them available to the subshell if `eval` is used or to `scripts/deploy_claude_infrastructure.sh` if called directly.
echo "Loading variables from .env file..."
set -a
if ! source "$ENV_FILE_PATH"; then
    echo "ERROR: Could not source the .env file. Please check its syntax." >&2
    set +a
    exit 1
fi
set +a
echo ".env file loaded successfully."

# Check 3: Existence and executability of the main deployment script
MAIN_DEPLOY_SCRIPT="./scripts/deploy_claude_infrastructure.sh"
echo -n "Checking for main deployment script ($MAIN_DEPLOY_SCRIPT)... "
if [ ! -f "$MAIN_DEPLOY_SCRIPT" ]; then
    echo "ERROR: Main deployment script NOT FOUND at $MAIN_DEPLOY_SCRIPT." >&2
    echo "       This script is essential. It should be part of the project structure." >&2
    errors_found=true
elif [ ! -x "$MAIN_DEPLOY_SCRIPT" ]; then
    echo "ERROR: Main deployment script at $MAIN_DEPLOY_SCRIPT is NOT EXECUTABLE." >&2
    echo "       Please run: chmod +x $MAIN_DEPLOY_SCRIPT" >&2
    errors_found=true
else
    echo "OK."
fi

if [ "${errors_found:-false}" = true ]; then
    echo "-----------------------------------------------------------"
    echo "❌ Please address the errors above with the main deployment script before proceeding."
    echo "-----------------------------------------------------------"
    exit 1
fi

# Construct the command using variables sourced from .env
# Note: Variables like TARGET_SERVER_IP are now directly available in this shell
CMD="$MAIN_DEPLOY_SCRIPT"
CMD+=" --ip \"${TARGET_SERVER_IP}\""
CMD+=" --token \"${GITHUB_PAT}\""
CMD+=" --ssh-key \"${SSH_PUBLIC_KEY_PATH}\""

# Optional flags based on .env values (ensure they have defaults if not in .env)
# The .env.template provides defaults, so these should be set.
if [ "${CLAUDE_USER_NAME:-claude-user}" != "claude-user" ]; then
    CMD+=" --user \"${CLAUDE_USER_NAME}\""
fi

if [ "${DEPLOYMENT_MODE:-production}" != "production" ]; then
    CMD+=" --mode \"${DEPLOYMENT_MODE}\""
fi

# ENABLE_MCP_SERVER is expected to be "true" or "false" (as strings) in .env
if [ "${ENABLE_MCP_SERVER:-true}" == "false" ]; then
    CMD+=" --no-mcp"
fi

echo ""
echo "All checks passed. The .env file is configured and the main deployment script is ready."
echo ""
echo "Review the command that will be executed:"
echo "-----------------------------------------------------------"
echo "$CMD"
echo "-----------------------------------------------------------"

echo ""
echo "To execute the deployment:"
echo "1. Ensure you are in the project root directory (claude-code_infra)."
echo "2. Copy the command above and run it directly in your terminal."
echo "   OR"
echo "3. Uncomment and run the 'eval' line below (ensure this script is in the project root)."
echo "   # eval \"$CMD\""
echo ""
echo "After execution, proceed to './scripts/5_post_deployment_verification.sh' to verify the deployment."
echo "-----------------------------------------------------------"

# Make the script executable: chmod +x scripts/4_execute_deployment_template.sh
