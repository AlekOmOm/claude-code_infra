# Claude Code Infrastructure Orchestration

## Overview

The `run.sh` script is the main entry point for the Claude Code infrastructure deployment and management. It intelligently orchestrates the entire workflow, from initial setup through deployment to daily usage.

## Quick Start

```bash
cd /path/to/claude-code_infra
./scripts/phases/run.sh
```

## Workflow Logic

### 1. Configuration Check

The script first checks if your `.env` file has all required configuration values:

- **If configuration is complete**: Skips directly to deployment status check
- **If configuration is incomplete**: Automatically runs phases 1-3:
  - Phase 1: Prerequisites check
  - Phase 2: Information gathering (server IP, SSH key, tokens)
  - Phase 3: Deployment configuration (user, mode, MCP settings)

### 2. Deployment Status Check

Using `deploy_check_utils.sh`, the script determines if Claude Code is:

- **Not deployed**: Prompts to deploy
- **Partially deployed**: Prompts to complete deployment
- **Fully deployed**: Proceeds to environment health check

### 3. Environment Health Check

For deployed systems, `remote_environment_check.sh` verifies:

- SSH connectivity
- Service status (claude-code, mcp-server)
- System resources (memory, disk, CPU)
- Claude CLI availability
- Firewall configuration

### 4. Action Based on Status

#### If Not Deployed:
```
Would you like to deploy now? (y/n)
```
- Runs phase 4 (deployment)
- Runs phase 5 (verification)

#### If Partially Deployed:
```
Would you like to complete the deployment? (y/n)
```
- Completes missing components
- Runs verification

#### If Deployed and Healthy:
```
Would you like to connect to Claude Code now? (y/n)
```
- SSHs into the server as claude-user
- Launches Claude in the project directory
- Returns to menu on exit

#### If Deployed but Unhealthy:
- Automatically runs phase 5 verification
- Attempts fixes for common issues

## Utility Scripts

### deploy_check_utils.sh

Checks deployment status by verifying:
- Claude user exists
- Claude Code is installed
- Systemd services are configured
- Workspaces directory exists
- Node.js is installed

Returns: `"deployed"`, `"partial"`, or `"not_deployed"`

### remote_environment_check.sh

Performs health checks including:
- Service status monitoring
- Resource usage analysis
- Network connectivity verification
- Claude environment validation

Returns: `"healthy"`, `"degraded"`, or `"unhealthy"`

## Configuration Variables

The orchestrator uses these key variables from `.env`:

```bash
TARGET_SERVER_IP          # Ubuntu server IP
SSH_KEY_PATH             # Path to SSH public key
GITHUB_PAT               # GitHub Personal Access Token
ANTHROPIC_API_KEY        # Anthropic API key
CLAUDE_USER              # Service user (default: claude-user)
DEPLOY_MODE              # production/staging/dev
ENABLE_MCP_SERVER        # true/false
CLAUDE_PROJECT_DIR       # Project directory to launch Claude in
```

## Advanced Usage

### Skip Straight to Connection

If your system is already deployed and configured:
```bash
# .env file already complete
./scripts/phases/run.sh
# Automatically detects deployed state
# Prompts to connect immediately
```

### Force Re-deployment

To force a fresh deployment:
```bash
rm DEPLOYMENT_SUMMARY.md
./scripts/phases/run.sh
```

### Check Status Only

To see deployment and health status without taking action:
```bash
./scripts/implementation/utils/deploy_check_utils.sh
./scripts/implementation/utils/remote_environment_check.sh
```

## Troubleshooting

### "Configuration incomplete" keeps appearing
- Check `.env` file for placeholder values
- Ensure all values are not set to `YOUR_*_HERE`

### "SSH connection failed"
- Verify server IP in `.env`
- Check SSH key path and permissions
- Ensure server is accessible

### "Services not active"
- The orchestrator will automatically run verification
- Check service logs: `journalctl -u claude-code.service`

### "Claude command not found"
- May indicate partial deployment
- Choose to complete deployment when prompted

## Exit Codes

- `0`: Success
- `1`: Configuration or deployment error
- Other: Phase-specific error codes

## Best Practices

1. **First Run**: Let the orchestrator guide you through all phases
2. **Daily Use**: Just run `./scripts/phases/run.sh` to connect
3. **Updates**: Re-run to apply configuration changes
4. **Monitoring**: Use health check utilities for system status

## Integration with CI/CD

The orchestrator can be used in automated workflows:

```bash
# Non-interactive deployment
export AUTO_APPROVE=yes
./scripts/phases/run.sh
```

## Security Notes

- SSH keys are never stored in the repository
- Tokens are kept in local `.env` file only
- Firewall rules restrict access to local network
- Services run with systemd security hardening