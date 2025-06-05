#!/bin/bash
# Phase 3: Deployment Configuration Choices

echo "Phase 3: Deployment Configuration Choices Guide"
echo "---------------------------------------------------------"
echo "The main deployment script (scripts/deploy_claude_infrastructure.sh) accepts several optional flags to customize your deployment:"

echo "
1. Claude User Name (--user):"
echo "   - Purpose: Specifies the dedicated username for the Claude Code service on the target Ubuntu server."
echo "   - Default: 'claude-user'"
echo "   - Example: --user my-claude-svc"

echo "
2. Deployment Mode (--mode):"
echo "   - Purpose: Sets the deployment mode, which might influence certain configurations (though not explicitly detailed in current Terraform, it's good practice)."
echo "   - Options: 'dev', 'staging', 'production'"
echo "   - Default: 'production'"
echo "   - Example: --mode staging"

echo "
3. Enable MCP Server (--no-mcp):"
echo "   - Purpose: Controls whether the Model Context Protocol (MCP) server is deployed and enabled alongside the Claude Code service."
echo "   - Default: MCP server IS enabled."
echo "   - Flag: Use '--no-mcp' to DISABLE the MCP server deployment."
echo "   - Example: --no-mcp"

echo "
Required parameters (to be used with scripts/deploy_claude_infrastructure.sh):"
echo "   --token YOUR_GITHUB_PAT"
echo "   --ssh-key /path/to/your/ssh_public_key.pub"
echo "   --ip YOUR_SERVER_IP"

echo "---------------------------------------------------------"
echo "Consider these choices before running the main deployment script."
echo "Refer to 'docs/core-components/README.md' for more details."
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/3_deployment_configuration_guide.sh
