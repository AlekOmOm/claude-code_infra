#!/bin/bash
# Phase 5: Post-Deployment Checks & Considerations

echo "Phase 5: Post-Deployment Checks & Considerations"
echo "---------------------------------------------------------"

eCLAUDE_USER="claude-user"      # Use the same user as in deployment, or make this a parameter
SERVER_IP="YOUR_SERVER_IP_HERE" # Replace with the actual server IP

echo "Important: Some of these commands need to be run ON THE SERVER,
and some are reminders for checks on your GitHub repository."
echo "Replace placeholders like YOUR_SERVER_IP_HERE and ensure SSH access to the server."

echo "
1. Networking Configuration (Run on Server):"
echo "   - Review UFW firewall rules. Pay special attention to rules for your client network."
echo "     Command to check UFW status: ssh $CLAUDE_USER@$SERVER_IP sudo ufw status verbose"
echo "   - If your client network is not 192.168.1.0/24 or 10.0.0.0/8, you might need to adjust rules."

echo "
2. Service Status (Run on Server):"
echo "   - Check claude-code.service status:"
echo "     ssh $CLAUDE_USER@$SERVER_IP systemctl status claude-code.service --no-pager"
echo "   - If MCP server was enabled, check its status:"
echo "     ssh $CLAUDE_USER@$SERVER_IP systemctl status claude-mcp-server.service --no-pager"

echo "
3. Claude Code Installation Test (Run on Server):"
echo "   - Test claude CLI as the claude user:"
echo "     ssh $CLAUDE_USER@$SERVER_IP 'sudo -u $CLAUDE_USER bash -c "source ~/.bashrc && claude --version"'"

echo "
4. GitHub Workflow Secrets (Check in your GitHub Repository Settings):"
echo "   - [ ] Verify ANTHROPIC_API_KEY: Ensure this secret is set in your GitHub repository where the PR review workflow runs."
echo "   - [ ] Verify GITHUB_TOKEN (if customized for workflow): The PR review workflow uses secrets.GITHUB_TOKEN. If you used a custom PAT for workflows, verify it."

echo "
5. DEPLOYMENT_SUMMARY.md (Check in your local project root):"
echo "   - [ ] Verify that 'DEPLOYMENT_SUMMARY.md' has been created in your local project root."
echo "     Command: ls -l DEPLOYMENT_SUMMARY.md"

echo "
6. Access Information (from DEPLOYMENT_SUMMARY.md or known config):"
echo "   - SSH Access: ssh $CLAUDE_USER@$SERVER_IP"
echo "   - Claude Workspace on server: /home/$CLAUDE_USER/workspaces/"
echo "   - MCP Server URL (if enabled): http://$SERVER_IP:9090 (Test with: curl http://$SERVER_IP:9090/health)"

echo "
7. Audit Logging Status (Run on Server):"
echo "   - Check if auditd service is active:"
echo "     ssh $CLAUDE_USER@$SERVER_IP systemctl is-active auditd"

echo "---------------------------------------------------------"
echo "Perform these checks to ensure your deployment is functioning as expected."
echo "Refer to 'docs/core-components/9-testing-troubleshooting-guide.md' for more detailed troubleshooting."
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/5_post_deployment_verification.sh
