# Core System Inputs & Setup Guide

This guide outlines the necessary inputs and prerequisites to deploy the Claude Code Infrastructure. The system is deployed using Terraform, orchestrated by a main deployment script.

## Phase 1: Prerequisites for Your Control Machine

Before you begin, ensure the machine you'll use to run the deployment script has the following installed:
- [ ] **Terraform**: Version 1.5.0 or higher. (Verify with `terraform --version`)
- [ ] **Node.js and npm**: Node.js 20 LTS recommended. (Verify with `node --version` and `npm --version`)
- [ ] **Git**: (Verify with `git --version`)
- [ ] **GitHub CLI (`gh`)**: (Verify with `gh --version`)
- [ ] **Project Files**: Clone or download the `claude-code_infra` repository.

## Phase 2: Information and Credentials to Gather

You will need the following information and credentials to configure the deployment:

### 1. Target Ubuntu Server Details
   Ref: [Main Infrastructure Module](./1-main-infrastructure-module.md)
   - [ ] **Server IP Address**: The IP address of the Ubuntu server where Claude Code will be deployed.
     *   If using a local server: e.g., `192.168.1.100`.
     *   If using Google Cloud: Update `.env.gcloud` and ensure this IP is correctly sourced or provided.
   - [ ] **SSH Access**: Ensure your control machine can SSH into the target server for initial setup if manual steps were ever needed (Terraform aims to automate this).

### 2. SSH Public Key
   Ref: [Main Infrastructure Module](./1-main-infrastructure-module.md), [Security Hardening Module](./2-security-hardening-module.md)
   - [ ] **SSH Public Key File Path**: The path to your SSH public key file (e.g., `~/.ssh/id_rsa.pub`). This key will be authorized for the dedicated Claude user on the target server.

### 3. GitHub Personal Access Token (PAT)
   Ref: [Main Infrastructure Module](./1-main-infrastructure-module.md), [Claude Code Setup Module](./3-claude-code-setup-module.md), [MCP Server Implementation](./6-mcp-server-implementation.md)
   - [ ] **GitHub PAT**: A GitHub Personal Access Token with permissions for:
     *   Repository access (clone, push if auto-fixes are used by workflows).
     *   Pull request interaction (read, comment, create).
     *   `gh auth login` capabilities.
     *   This token will be used by Terraform (`var.github_token`) and potentially by the `claude-user` for GitHub CLI operations.

### 4. Anthropic API Key (for PR Review Workflow)
   Ref: [GitHub MCP Integration and PR Workflow](./5-github-mcp-integration-pr-workflow.md)
   - [ ] **Anthropic API Key**: Your API key from Anthropic.
     *   This key needs to be configured as a GitHub Secret named `ANTHROPIC_API_KEY` in the GitHub repository where the PR review workflow (`.github/workflows/claude-pr-review.yml`) will run.

## Phase 3: Deployment Configuration Choices

The main deployment script (`scripts/deploy_claude_infrastructure.sh`) allows for the following configurations:

### 1. Claude User Name (Optional)
   Ref: [Main Infrastructure Module](./1-main-infrastructure-module.md)
   - [ ] **Dedicated User Name**: The username for the service account on the Ubuntu server.
     *   Default: `claude-user`.
     *   Provide via `--user` flag if changing.

### 2. Deployment Mode (Optional)
   Ref: [Complete Setup and Deployment Scripts](./8-complete-setup-deployment-scripts.md)
   - [ ] **Mode**: Deployment mode.
     *   Options: `dev | staging | production`.
     *   Default: `production`.
     *   Provide via `--mode` flag.

### 3. Enable MCP Server (Optional)
   Ref: [Complete Setup and Deployment Scripts](./8-complete-setup-deployment-scripts.md)
   - [ ] **MCP Server**: Whether to deploy and enable the MCP server.
     *   Default: `true` (enabled).
     *   Provide `--no-mcp` flag to disable.


## Phase 4: Running the Deployment
   Ref: [Complete Setup and Deployment Scripts](./8-complete-setup-deployment-scripts.md)

Once all prerequisites are met and information is gathered:
1.  Navigate to the project root directory.
2.  Execute the deployment script, providing the necessary arguments:
    ```bash
    cd /path/to/claude-code_infra
    scripts/deploy_claude_infrastructure.sh \
      --token YOUR_GITHUB_PAT \
      --ssh-key /path/to/your/ssh_public_key.pub \
      --ip YOUR_SERVER_IP \
      # Optional flags:
      # --user custom-claude-user \
      # --mode staging \
      # --no-mcp
    ```

## Phase 5: Post-Deployment Checks & Considerations

### Networking Configuration
   Ref: [Networking and Security Configuration](./7-networking-security-configuration.md)
   - [ ] **Firewall Rules**: The UFW firewall script (`scripts/configure_firewall.sh`) uses default local network ranges (e.g., `192.168.1.0/24`). If your local network setup is different, you may need to review and adjust these rules on the server post-deployment for full client access.
     *   Specifically check rules for `192.168.1.0/24` and `10.0.0.0/8`.

### GitHub Workflow Secrets
   Ref: [GitHub MCP Integration and PR Workflow](./5-github-mcp-integration-pr-workflow.md)
   - [ ] **Verify `ANTHROPIC_API_KEY` Secret**: Ensure the `ANTHROPIC_API_KEY` is correctly set in your GitHub repository secrets for the PR review workflow to function.
   - [ ] **Verify `GITHUB_TOKEN` Secret (if customized)**: The workflow uses `secrets.GITHUB_TOKEN`. Usually, the default GitHub Actions token is sufficient. If specific permissions require a custom PAT here, ensure it's set.

---

This guide provides the inputs for the system. For detailed explanations of each component, refer to their respective markdown files:
- [Main Infrastructure Module](./1-main-infrastructure-module.md)
- [Security Hardening Module](./2-security-hardening-module.md)
- [Claude Code Setup Module](./3-claude-code-setup-module.md)
- [Systemd Services Module](./4-systemd-services-module.md)
- [GitHub MCP Integration and PR Workflow](./5-github-mcp-integration-pr-workflow.md)
- [MCP Server Implementation](./6-mcp-server-implementation.md)
- [Networking and Security Configuration](./7-networking-security-configuration.md)
- [Complete Setup and Deployment Scripts](./8-complete-setup-deployment-scripts.md)
- [Testing and Troubleshooting Guide](./9-testing-troubleshooting-guide.md)  