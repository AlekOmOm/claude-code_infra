#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Implementation script to attempt fixes for post-deployment issues on a remote server.

TARGET_SERVER_IP=""
CLAUDE_USER=""
ACTIONS_TO_PERFORM=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    --server-ip)
        TARGET_SERVER_IP="$2"
        shift # past argument
        shift # past value
        ;;
    --user)
        CLAUDE_USER="$2"
        shift # past argument
        shift # past value
        ;;
    --fix-claude-service)
        ACTIONS_TO_PERFORM+=("fix_claude_service")
        shift # past argument
        ;;
    --fix-mcp-service)
        ACTIONS_TO_PERFORM+=("fix_mcp_service")
        shift # past argument
        ;;
    --fix-ufw)
        ACTIONS_TO_PERFORM+=("fix_ufw")
        shift # past argument
        ;;
    --fix-auditd)
        ACTIONS_TO_PERFORM+=("fix_auditd")
        shift # past argument
        ;;
    *)
        echo "Unknown option: $1" >&2
        # Optionally, print usage here
        exit 1
        ;;
    esac
done

if [ -z "$TARGET_SERVER_IP" ] || [ -z "$CLAUDE_USER" ]; then
    echo "Error: --server-ip and --user are required arguments." >&2
    # Optionally, print usage here
    exit 1
fi

if [ ${#ACTIONS_TO_PERFORM[@]} -eq 0 ]; then
    echo "No fix actions specified. Exiting."
    exit 0
fi

echo "Attempting fixes on server: $TARGET_SERVER_IP as user: $CLAUDE_USER"
echo "Ensure SSH key-based authentication is configured for $CLAUDE_USER@$TARGET_SERVER_IP."

# Helper function to run remote commands
run_remote_ssh_command() {
    local cmd_description="$1"
    local remote_cmd="$2"
    echo "---------------------------------------------------------"
    echo "Attempting: $cmd_description"
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "${CLAUDE_USER}@${TARGET_SERVER_IP}" "${remote_cmd}"; then
        echo "Successfully executed: $cmd_description"
    else
        echo "Error executing: $cmd_description. Manual intervention may be required." >&2
        # Decide if we should exit or continue with other fixes
        # For now, we will continue.
    fi
    echo "---------------------------------------------------------"
}

for action in "${ACTIONS_TO_PERFORM[@]}"; do
    case $action in
    fix_claude_service)
        run_remote_ssh_command "Start Claude Code service and check status" \
            "sudo systemctl start claude-code.service && sudo systemctl status claude-code.service --no-pager && echo 'claude-code.service started.' || echo 'Failed to start claude-code.service.'"
        ;;
    fix_mcp_service)
        run_remote_ssh_command "Start Claude MCP service and check status" \
            "sudo systemctl start claude-mcp-server.service && sudo systemctl status claude-mcp-server.service --no-pager && echo 'claude-mcp-server.service started.' || echo 'Failed to start claude-mcp-server.service.'"
        ;;
    fix_ufw)
        run_remote_ssh_command "Enable UFW firewall and check status" \
            "echo -e \"y\\n\" | sudo ufw enable && sudo ufw status verbose && echo 'UFW enabled.' || echo 'Failed to enable UFW.'"
        ;;
    fix_auditd)
        run_remote_ssh_command "Start Auditd service and check status" \
            "sudo systemctl start auditd && sudo systemctl status auditd --no-pager && echo 'auditd service started.' || echo 'Failed to start auditd service.'"
        ;;
    esac
done

echo "All specified fix attempts are complete."
