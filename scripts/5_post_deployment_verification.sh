#!/bin/bash
# Phase 5: Post-Deployment Checks & Considerations

echo "Phase 5: Post-Deployment Checks & Considerations"
echo "---------------------------------------------------------"

# --- Configuration - Ensure these are set correctly! ---
# You can set these as environment variables, or modify them directly here.
# The script will prompt if they remain as placeholders.
TARGET_SERVER_IP="${TARGET_SERVER_IP:-YOUR_SERVER_IP_HERE}" # Replace or set env var
CLAUDE_USER="${CLAUDE_USER:-claude-user}"      # Use the same user as in deployment
# This will be determined more accurately below
SHOULD_MCP_BE_ACTIVE=false

# --- End Configuration ---

remediable_issues_args=()
all_critical_placeholders_set=true

if [[ "$TARGET_SERVER_IP" == "YOUR_SERVER_IP_HERE" ]]; then
    echo "ERROR: TARGET_SERVER_IP is not set in the script. Please edit the script or set the environment variable."
    all_critical_placeholders_set=false
fi

if ! $all_critical_placeholders_set; then
    echo "---------------------------------------------------------"
    echo "❌ Critical placeholders not set. Exiting."
    echo "---------------------------------------------------------"
    exit 1
fi

echo "Using Server IP: $TARGET_SERVER_IP, User: $CLAUDE_USER"
echo "Important: Some of these commands run ON THE SERVER via SSH."
echo "Ensure SSH key-based authentication is set up for $CLAUDE_USER@$TARGET_SERVER_IP or you may be prompted for a password."

# Function to check remote status and collect remediable issues
# $1: Readable name of the check (e.g., "Claude Code Service")
# $2: SSH command to check status (e.g., "systemctl is-active claude-code.service")
# $3: Expected output for success (e.g., "active")
# $4: Argument for the fix script if this check fails (e.g., "claude-service")
# $5: Optional - set to true if this check should only run if SHOULD_MCP_BE_ACTIVE is true
check_remote_status() {
    local check_name="$1"
    local ssh_check_cmd="$2"
    local expected_status="$3"
    local fix_arg="$4"
    local only_if_mcp_active=${5:-false}

    if $only_if_mcp_active; then
        # This check depends on SHOULD_MCP_BE_ACTIVE
        # Ensure it's evaluated correctly as a command, not a string comparison to 'true'
        if ! $SHOULD_MCP_BE_ACTIVE; then
            echo "[SKIPPED] $check_name (MCP Server not determined to be active/deployed)"
            return
        fi
    fi

    echo -n "Checking $check_name status on $TARGET_SERVER_IP... "
    local remote_status
    remote_status=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$CLAUDE_USER@$TARGET_SERVER_IP" "$ssh_check_cmd" 2>/dev/null || echo "ssh_or_command_error")

    if [[ "$remote_status" == "ssh_or_command_error" ]]; then
        echo "SSH Error or command failed on remote."
        echo "  └─ Failed to connect or execute command for $check_name. Manual check required."
    elif [[ "$remote_status" == "$expected_status" ]]; then
        echo "OK ($remote_status)."
    else
        echo "Issue Found (Observed: '$remote_status', Expected: '$expected_status')."
        echo "  └─ $check_name is not in the expected state."
        if [[ ! " ${remediable_issues_args[@]} " =~ " --fix-$fix_arg " ]]; then # Avoid duplicates
            remediable_issues_args+=( "--fix-$fix_arg" )
        fi
    fi
}

echo ""
1. Service Status Checks (on Server):
echo "1. Service Status Checks (on Server):"

# Determine if MCP service *should* be active by checking for its service file
echo -n "Determining expected MCP service status... "
ssh -o ConnectTimeout=5 -o BatchMode=yes "$CLAUDE_USER@$TARGET_SERVER_IP" "test -f /etc/systemd/system/claude-mcp-server.service" 2>/dev/null
ssh_exit_status=$?
if [ $ssh_exit_status -eq 0 ]; then
    echo "(claude-mcp-server.service file found on remote, assuming it should be active if deployed.)"
    SHOULD_MCP_BE_ACTIVE=true # Assigns the command 'true'
else
    echo "(claude-mcp-server.service file NOT found on remote or SSH error for check, assuming --no-mcp or not deployed.)"
    SHOULD_MCP_BE_ACTIVE=false # Assigns the command 'false'
fi
echo "" # Separator

check_remote_status "Claude Code Service" "systemctl is-active claude-code.service" "active" "claude-service"
echo "" # Separator
check_remote_status "Claude MCP Server" "systemctl is-active claude-mcp-server.service" "active" "mcp-service" true
echo "" # Separator
check_remote_status "UFW Firewall" "sudo ufw status | head -n 1 | awk '{print $2}'" "active" "ufw"
echo "" # Separator
check_remote_status "Auditd Service" "systemctl is-active auditd" "active" "auditd"

echo ""
2. Networking Configuration (Manual Review Reminder - Run on Server):
echo "   - Review UFW firewall rules, especially for your client network."
echo "     Command: ssh $CLAUDE_USER@$TARGET_SERVER_IP sudo ufw status verbose"

echo ""
3. Claude Code Installation Test (Run on Server):
echo "   - Test claude CLI as the claude user:"
echo "     ssh $CLAUDE_USER@$TARGET_SERVER_IP sudo -u $CLAUDE_USER bash -c \"source ~/.bashrc && claude --version\""

echo ""
4. GitHub Workflow Secrets (Check in your GitHub Repository Settings):
echo "   - [ ] Verify ANTHROPIC_API_KEY secret is set."
echo "   - [ ] Verify GITHUB_TOKEN secret (if customized for workflow)."

echo ""
5. DEPLOYMENT_SUMMARY.md (Check in your local project root):
echo "   - [ ] Verify 'DEPLOYMENT_SUMMARY.md' was created."
echo "     Command: ls -l DEPLOYMENT_SUMMARY.md"

echo ""
6. Access Information (from DEPLOYMENT_SUMMARY.md or known config):
echo "   - SSH: ssh $CLAUDE_USER@$TARGET_SERVER_IP"
echo "   - Claude Workspace: /home/$CLAUDE_USER/workspaces/"
if $SHOULD_MCP_BE_ACTIVE; then # Checks the command 'true' or 'false'
    echo "   - MCP Server URL: http://$TARGET_SERVER_IP:9090 (Test with: curl -sSf http://$TARGET_SERVER_IP:9090/health || echo 'MCP Health Check Failed')"
fi

echo "---------------------------------------------------------"

if [ ${#remediable_issues_args[@]} -gt 0 ]; then
    echo "❌ Some remediable issues were found with the deployment services on the server:"
    for issue_arg in "${remediable_issues_args[@]}"; do
        echo "   - Issue corresponding to fix: $issue_arg"
    done
    echo ""
    read -r -p "Attempt to run automated fixes on the server $TARGET_SERVER_IP? (Y/n): " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ || -z "$response" ]]; then
        echo "Proceeding with automated fixes..."
        fix_script_path="./scripts/implementation/5_attempt_post_deployment_fixes.sh"
        
        if [ ! -f "$fix_script_path" ]; then
            echo "ERROR: Fix script not found at $fix_script_path" >&2
            exit 1
        fi
        if [ ! -x "$fix_script_path" ]; then
            echo "ERROR: Fix script at $fix_script_path is not executable. Please run: chmod +x $fix_script_path" >&2
            exit 1
        fi

        fix_command="$fix_script_path --server-ip $TARGET_SERVER_IP --user $CLAUDE_USER ${remediable_issues_args[*]}"
        echo "Executing: $fix_command"
        eval "$fix_command"
        
        echo "---------------------------------------------------------"
        echo "Please re-run this verification script (5_post_deployment_verification.sh) after fixes to verify."
    else
        echo "Automated fixes skipped. Please address the issues manually on the server."
    fi
else
    echo "✅ No automatically remediable issues detected by this script for core services on the server."
    echo "   Please still review manual checks and GitHub secrets."
fi
echo "---------------------------------------------------------"
echo "Refer to 'docs/core-components/9-testing-troubleshooting-guide.md' for more detailed troubleshooting."
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/5_post_deployment_verification.sh
