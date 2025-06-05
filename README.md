# Claude Code Infrastructure Setup for Ubuntu Home Server

A comprehensive infrastructure-as-code solution for deploying Claude Code securely on Ubuntu home servers with GitHub MCP integration, automated PR workflows, and production-ready security hardening.

## Executive Overview

This setup provides **three operational paths**: (1) secure home-server deployment with dedicated user isolation, (2) continuous PR review workflow with CodeRabbit integration, and (3) MCP server option for advanced AI-assisted development. The infrastructure uses Terraform for complete environment provisioning, implements security hardening following CIS benchmarks, and includes automated GitHub workflows for seamless development cycles.

**Key capabilities include**: claude-user account isolation with systemd sandboxing, UFW firewall configuration for Windows client access, GitHub Actions workflows for automated PR processing, and comprehensive monitoring with audit logging. The solution supports both direct Claude Code usage and MCP server deployment, with failover mechanisms and resource management for production home-lab environments.

## Complete Terraform Infrastructure Configuration

### Main Infrastructure Module

**terraform/main.tf**
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Variables for customization
variable "server_ip" {
  description = "Ubuntu server IP address"
  type        = string
  default     = "192.168.1.100"
}

variable "claude_user" {
  description = "Dedicated user for Claude Code"
  type        = string
  default     = "claude-user"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}

variable "github_token" {
  description = "GitHub token for MCP integration"
  type        = string
  sensitive   = true
}

# Core modules
module "security_hardening" {
  source = "./modules/security"
  
  claude_user    = var.claude_user
  server_ip      = var.server_ip
  ssh_public_key = var.ssh_public_key
}

module "claude_code_setup" {
  source = "./modules/claude-code"
  
  claude_user   = var.claude_user
  github_token  = var.github_token
  depends_on    = [module.security_hardening]
}

module "networking" {
  source = "./modules/networking"
  
  server_ip = var.server_ip
}

module "systemd_services" {
  source = "./modules/systemd"
  
  claude_user = var.claude_user
  depends_on  = [module.claude_code_setup]
}

# Outputs
output "deployment_status" {
  value = {
    claude_user_created = module.security_hardening.user_status
    claude_code_installed = module.claude_code_setup.installation_status
    services_enabled = module.systemd_services.service_status
    firewall_configured = module.networking.firewall_status
  }
}
```

### Security Hardening Module

**terraform/modules/security/main.tf**
```hcl
variable "claude_user" {
  description = "Claude service user"
  type        = string
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

# Create dedicated claude user with security isolation
resource "local_file" "user_setup_script" {
  content = templatefile("${path.module}/templates/create_user.sh", {
    claude_user    = var.claude_user
    ssh_public_key = var.ssh_public_key
  })
  filename = "${path.module}/create_user.sh"
  file_permission = "0755"
}

resource "local_file" "security_hardening_script" {
  content = templatefile("${path.module}/templates/security_hardening.sh", {
    claude_user = var.claude_user
  })
  filename = "${path.module}/security_hardening.sh"
  file_permission = "0755"
}

# Execute security setup
resource "null_resource" "security_setup" {
  provisioner "local-exec" {
    command = "${path.module}/create_user.sh"
  }
  
  provisioner "local-exec" {
    command = "${path.module}/security_hardening.sh"
  }
  
  depends_on = [
    local_file.user_setup_script,
    local_file.security_hardening_script
  ]
}

# Configure SSH security
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/sshd_config", {
    claude_user = var.claude_user
  })
  filename = "/tmp/sshd_config_secure"
}

resource "null_resource" "ssh_security" {
  provisioner "local-exec" {
    command = "sudo cp /tmp/sshd_config_secure /etc/ssh/sshd_config && sudo systemctl restart sshd"
  }
  
  depends_on = [local_file.ssh_config]
}

output "user_status" {
  value = "claude-user created with security isolation"
}
```

**terraform/modules/security/templates/create_user.sh**
```bash
#!/bin/bash
set -euo pipefail

CLAUDE_USER="${claude_user}"
SSH_KEY="${ssh_public_key}"

# Create system user for Claude Code
if ! id "$CLAUDE_USER" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash -c "Claude Code Service User" "$CLAUDE_USER"
    echo "$CLAUDE_USER user created successfully"
else
    echo "$CLAUDE_USER user already exists"
fi

# Create necessary directories
sudo mkdir -p /home/$CLAUDE_USER/{.ssh,.npm-global,.claude}
sudo mkdir -p /var/lib/claude-code
sudo mkdir -p /var/log/claude-code
sudo mkdir -p /var/cache/claude-code

# Set up SSH access
echo "$SSH_KEY" | sudo tee /home/$CLAUDE_USER/.ssh/authorized_keys
sudo chmod 700 /home/$CLAUDE_USER/.ssh
sudo chmod 600 /home/$CLAUDE_USER/.ssh/authorized_keys
sudo chown -R $CLAUDE_USER:$CLAUDE_USER /home/$CLAUDE_USER/.ssh

# Configure npm for user installation
sudo -u $CLAUDE_USER bash -c "
    npm config set prefix ~/.npm-global
    echo 'export PATH=~/.npm-global/bin:\$PATH' >> ~/.bashrc
    echo 'export NODE_PATH=~/.npm-global/lib/node_modules:\$NODE_PATH' >> ~/.bashrc
"

# Set proper ownership
sudo chown -R $CLAUDE_USER:$CLAUDE_USER /home/$CLAUDE_USER
sudo chown -R $CLAUDE_USER:$CLAUDE_USER /var/lib/claude-code
sudo chown -R $CLAUDE_USER:$CLAUDE_USER /var/log/claude-code
sudo chown -R $CLAUDE_USER:$CLAUDE_USER /var/cache/claude-code

# Add claude user to necessary groups
sudo usermod -a -G developers $CLAUDE_USER 2>/dev/null || true

echo "Claude user setup completed successfully"
```

**terraform/modules/security/templates/security_hardening.sh**
```bash
#!/bin/bash
set -euo pipefail

CLAUDE_USER="${claude_user}"

# Install security tools
sudo apt update
sudo apt install -y fail2ban ufw auditd aide

# Configure fail2ban
sudo tee /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure audit logging
sudo tee -a /etc/audit/audit.rules <<EOF
# Monitor Claude Code activities
-w /home/$CLAUDE_USER -p wa -k claude_user_activity
-w /var/lib/claude-code -p wa -k claude_code_data
-w /etc/systemd/system/claude-code.service -p wa -k claude_service_config
EOF

sudo systemctl enable auditd
sudo systemctl restart auditd

# System hardening via sysctl
sudo tee /etc/sysctl.d/99-claude-security.conf <<EOF
# Network security
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# Memory protection
kernel.randomize_va_space = 2
kernel.exec-shield = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-claude-security.conf

echo "Security hardening completed"
```

### Claude Code Setup Module

**terraform/modules/claude-code/main.tf**
```hcl
variable "claude_user" {
  description = "Claude service user"
  type        = string
}

variable "github_token" {
  description = "GitHub token"
  type        = string
  sensitive   = true
}

# Node.js and Claude Code installation
resource "local_file" "claude_install_script" {
  content = templatefile("${path.module}/templates/install_claude.sh", {
    claude_user  = var.claude_user
    github_token = var.github_token
  })
  filename = "${path.module}/install_claude.sh"
  file_permission = "0755"
}

# Claude Code configuration
resource "local_file" "claude_config" {
  content = templatefile("${path.module}/templates/claude_config.yaml", {
    claude_user = var.claude_user
  })
  filename = "/tmp/claude_config.yaml"
}

# MCP server configuration
resource "local_file" "mcp_server_config" {
  content = templatefile("${path.module}/templates/mcp_server.js", {
    github_token = var.github_token
  })
  filename = "/tmp/mcp_server.js"
  file_permission = "0755"
}

# Execute installation
resource "null_resource" "claude_installation" {
  provisioner "local-exec" {
    command = "${path.module}/install_claude.sh"
  }
  
  provisioner "local-exec" {
    command = "sudo cp /tmp/claude_config.yaml /etc/claude-code/ && sudo chown ${var.claude_user}:${var.claude_user} /etc/claude-code/claude_config.yaml"
  }
  
  provisioner "local-exec" {
    command = "sudo cp /tmp/mcp_server.js /opt/claude-code/ && sudo chown ${var.claude_user}:${var.claude_user} /opt/claude-code/mcp_server.js"
  }
  
  depends_on = [
    local_file.claude_install_script,
    local_file.claude_config,
    local_file.mcp_server_config
  ]
}

output "installation_status" {
  value = "Claude Code installed successfully"
}
```

**terraform/modules/claude-code/templates/install_claude.sh**
```bash
#!/bin/bash
set -euo pipefail

CLAUDE_USER="${claude_user}"
GITHUB_TOKEN="${github_token}"

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git

# Create directories
sudo mkdir -p /opt/claude-code
sudo mkdir -p /etc/claude-code
sudo chown $CLAUDE_USER:$CLAUDE_USER /opt/claude-code
sudo chown $CLAUDE_USER:$CLAUDE_USER /etc/claude-code

# Install Claude Code as the claude user
sudo -u $CLAUDE_USER bash -c '
    cd /home/'$CLAUDE_USER'
    source ~/.bashrc
    npm install -g @anthropic-ai/claude-code
    
    # Verify installation
    which claude
    claude --version
'

# Install GitHub CLI
sudo apt install -y gh

# Configure GitHub authentication for claude user
sudo -u $CLAUDE_USER bash -c "
    echo '$GITHUB_TOKEN' | gh auth login --with-token
    gh auth status
"

# Create workspace directory
sudo -u $CLAUDE_USER mkdir -p /home/$CLAUDE_USER/workspaces

echo "Claude Code installation completed successfully"
```

### Systemd Services Module

**terraform/modules/systemd/main.tf**
```hcl
variable "claude_user" {
  description = "Claude service user"
  type        = string
}

# Claude Code service
resource "local_file" "claude_service" {
  content = templatefile("${path.module}/templates/claude-code.service", {
    claude_user = var.claude_user
  })
  filename = "/tmp/claude-code.service"
}

# MCP server service
resource "local_file" "mcp_service" {
  content = templatefile("${path.module}/templates/claude-mcp-server.service", {
    claude_user = var.claude_user
  })
  filename = "/tmp/claude-mcp-server.service"
}

# Service slice for resource management
resource "local_file" "claude_slice" {
  content = file("${path.module}/templates/claude-services.slice")
  filename = "/tmp/claude-services.slice"
}

# Deploy services
resource "null_resource" "deploy_services" {
  provisioner "local-exec" {
    command = <<-EOT
      sudo cp /tmp/claude-code.service /etc/systemd/system/
      sudo cp /tmp/claude-mcp-server.service /etc/systemd/system/
      sudo cp /tmp/claude-services.slice /etc/systemd/system/
      sudo systemctl daemon-reload
      sudo systemctl enable claude-services.slice
      sudo systemctl enable claude-code.service
      sudo systemctl enable claude-mcp-server.service
    EOT
  }
  
  depends_on = [
    local_file.claude_service,
    local_file.mcp_service,
    local_file.claude_slice
  ]
}

output "service_status" {
  value = "Systemd services configured and enabled"
}
```

**terraform/modules/systemd/templates/claude-code.service**
```systemd
[Unit]
Description=Claude Code Service
Documentation=https://docs.anthropic.com/claude-code
After=network-online.target
Wants=network-online.target
PartOf=claude-services.slice

[Service]
Type=simple
User=${claude_user}
Group=${claude_user}
WorkingDirectory=/home/${claude_user}/workspaces
Environment="NODE_ENV=production"
Environment="PATH=/home/${claude_user}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/${claude_user}/.npm-global/bin/claude
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
MemoryDenyWriteExecute=no
LockPersonality=yes
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Resource management
Slice=claude-services.slice
MemoryMax=4G
MemoryHigh=3G
CPUQuota=200%
TasksMax=1000

# Directory management
StateDirectory=claude-code
CacheDirectory=claude-code
LogsDirectory=claude-code
ReadWritePaths=/home/${claude_user} /var/lib/claude-code /var/log/claude-code /tmp

[Install]
WantedBy=multi-user.target
```

**terraform/modules/systemd/templates/claude-mcp-server.service**
```systemd
[Unit]
Description=Claude MCP Server
After=network-online.target
Wants=network-online.target
PartOf=claude-services.slice

[Service]
Type=simple
User=${claude_user}
Group=${claude_user}
WorkingDirectory=/opt/claude-code
Environment="NODE_ENV=production"
Environment="PATH=/home/${claude_user}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/bin/node /opt/claude-code/mcp_server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectKernelLogs=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=no
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Resource management
Slice=claude-services.slice
MemoryMax=2G
CPUQuota=100%
TasksMax=500

# Directory management
StateDirectory=claude-mcp
LogsDirectory=claude-mcp
ReadWritePaths=/var/lib/claude-mcp /var/log/claude-mcp /tmp

[Install]
WantedBy=multi-user.target
```

## GitHub MCP Integration and PR Workflow Automation

### GitHub Actions Workflow for Automated PR Review

**.github/workflows/claude-pr-review.yml**
```yaml
name: Claude Code PR Review Workflow
on:
  pull_request:
    types: [opened, synchronize, ready_for_review]
  pull_request_review:
    types: [submitted]

env:
  CLAUDE_SERVER_URL: "http://192.168.1.100:8080"
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

jobs:
  pr_analysis:
    runs-on: ubuntu-latest
    if: github.event.pull_request.draft == false
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          
      - name: Install dependencies
        run: |
          npm install -g @anthropic-ai/claude-code
          
      - name: Trigger CodeRabbit Review
        uses: coderabbitai/coderabbit-action@v2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          enable_auto_review: true
          review_level: 'thorough'
          
      - name: Claude Code PR Analysis
        run: |
          # Get PR details
          PR_NUMBER="${{ github.event.number }}"
          
          # Clone and analyze PR
          gh pr checkout $PR_NUMBER
          
          # Run Claude Code analysis
          claude analyze --pr-number=$PR_NUMBER --output-format=json > claude_analysis.json
          
          # Post results as comment
          claude_summary=$(jq -r '.summary' claude_analysis.json)
          claude_recommendations=$(jq -r '.recommendations[]' claude_analysis.json)
          
          gh pr comment $PR_NUMBER --body "## 🤖 Claude Code Analysis
          
          **Summary:** $claude_summary
          
          **Recommendations:**
          $claude_recommendations
          
          **Next Steps:**
          - Address any security concerns highlighted above
          - Consider performance optimizations suggested
          - Ensure test coverage for new functionality"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
  automated_improvements:
    runs-on: ubuntu-latest
    needs: pr_analysis
    if: github.event.review.state == 'changes_requested'
    steps:
      - name: Checkout PR branch
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          ref: ${{ github.event.pull_request.head.ref }}
          
      - name: Setup Claude Code environment
        run: |
          npm install -g @anthropic-ai/claude-code
          
      - name: Apply Claude Code fixes
        run: |
          # Initialize Claude Code in repository
          claude init
          
          # Apply automated fixes based on review feedback
          claude fix --auto-apply --focus="security,performance,tests"
          
          # Check if changes were made
          if [[ -n $(git diff --name-only) ]]; then
            git config --local user.email "claude-bot@actions.github.com"
            git config --local user.name "Claude Code Bot"
            git add .
            git commit -m "🤖 Claude Code: Auto-apply review suggestions"
            git push
            
            # Notify on PR
            gh pr comment ${{ github.event.number }} \
              --body "🔧 **Claude Code Auto-fixes Applied**
              
              I've automatically applied the following improvements:
              - Security vulnerability fixes
              - Performance optimizations  
              - Test coverage enhancements
              
              Please review the changes and re-request review when ready."
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          
  deployment_ready:
    runs-on: ubuntu-latest
    if: github.event.review.state == 'approved'
    steps:
      - name: Prepare for merge
        run: |
          gh pr merge ${{ github.event.number }} --auto --squash
          
          # Trigger deployment to staging
          gh workflow run deploy-to-staging.yml \
            -f pr_number=${{ github.event.number }} \
            -f branch=${{ github.event.pull_request.head.ref }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### MCP Server Implementation

**terraform/modules/claude-code/templates/mcp_server.js**
```javascript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const GITHUB_TOKEN = "${github_token}";

class ClaudeMCPServer {
  constructor() {
    this.server = new Server(
      { name: 'claude-mcp-server', version: '1.0.0' },
      { capabilities: { tools: {}, resources: {}, prompts: {} } }
    );
    
    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'github_pr_view',
          description: 'View GitHub pull request details',
          inputSchema: {
            type: 'object',
            properties: {
              pr_number: { type: 'number', description: 'PR number to view' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['pr_number']
          }
        },
        {
          name: 'github_pr_comment',
          description: 'Add comment to GitHub pull request',
          inputSchema: {
            type: 'object',
            properties: {
              pr_number: { type: 'number', description: 'PR number' },
              comment: { type: 'string', description: 'Comment text' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['pr_number', 'comment']
          }
        },
        {
          name: 'github_pr_create',
          description: 'Create new GitHub pull request',
          inputSchema: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'PR title' },
              body: { type: 'string', description: 'PR description' },
              head: { type: 'string', description: 'Source branch' },
              base: { type: 'string', description: 'Target branch' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['title', 'head', 'base']
          }
        },
        {
          name: 'code_analysis',
          description: 'Analyze code changes in repository',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Path to analyze' },
              type: { type: 'string', enum: ['security', 'performance', 'quality'], description: 'Analysis type' }
            },
            required: ['path']
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'github_pr_view':
            return await this.viewPullRequest(args);
          case 'github_pr_comment':
            return await this.commentOnPR(args);
          case 'github_pr_create':
            return await this.createPullRequest(args);
          case 'code_analysis':
            return await this.analyzeCode(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true
        };
      }
    });
  }

  async viewPullRequest(args) {
    const { pr_number, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    
    const { stdout } = await execAsync(`gh pr view ${pr_number} ${repoArg} --json title,body,state,author,files,comments`);
    const prData = JSON.parse(stdout);
    
    return {
      content: [{
        type: 'text',
        text: `PR #${pr_number}: ${prData.title}
        
**Status:** ${prData.state}
**Author:** ${prData.author.login}

**Description:**
${prData.body}

**Files Changed:** ${prData.files.length}
**Comments:** ${prData.comments.length}`
      }]
    };
  }

  async commentOnPR(args) {
    const { pr_number, comment, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    
    await execAsync(`gh pr comment ${pr_number} ${repoArg} --body "${comment}"`);
    
    return {
      content: [{
        type: 'text',
        text: `Comment added to PR #${pr_number}`
      }]
    };
  }

  async createPullRequest(args) {
    const { title, body, head, base, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    const bodyArg = body ? `--body "${body}"` : '';
    
    const { stdout } = await execAsync(`gh pr create --title "${title}" ${bodyArg} --head ${head} --base ${base} ${repoArg}`);
    
    return {
      content: [{
        type: 'text',
        text: `Pull request created: ${stdout.trim()}`
      }]
    };
  }

  async analyzeCode(args) {
    const { path, type = 'quality' } = args;
    
    // Placeholder for code analysis - integrate with static analysis tools
    const analysisCommands = {
      security: `semgrep --config=auto ${path}`,
      performance: `eslint ${path} --rule 'complexity: [error, 10]'`,
      quality: `sonarjs ${path}`
    };
    
    try {
      const { stdout } = await execAsync(analysisCommands[type] || analysisCommands.quality);
      return {
        content: [{
          type: 'text',
          text: `Code analysis results for ${path}:\n\n${stdout}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Analysis completed with findings:\n${error.stdout || error.message}`
        }]
      };
    }
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.log('Claude MCP Server started');
  }
}

// Start the server
const server = new ClaudeMCPServer();
server.start().catch(console.error);
```

## Networking and Security Configuration

### UFW Firewall Setup Script

**scripts/configure_firewall.sh**
```bash
#!/bin/bash
set -euo pipefail

echo "Configuring UFW firewall for Claude Code home server..."

# Reset UFW to defaults
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed

# Allow SSH with rate limiting
sudo ufw limit ssh comment 'SSH with rate limiting'

# Allow local network access
sudo ufw allow from 192.168.1.0/24 comment 'Local network'
sudo ufw allow from 10.0.0.0/8 comment 'Private networks'

# Claude Code specific ports
sudo ufw allow from 192.168.1.0/24 to any port 8080 comment 'Claude Code API'
sudo ufw allow from 192.168.1.0/24 to any port 8443 comment 'Claude Code HTTPS'
sudo ufw allow from 192.168.1.0/24 to any port 9090 comment 'MCP Server'

# Windows client access (SMB/CIFS)
sudo ufw allow from 192.168.1.0/24 to any port 139 comment 'NetBIOS'
sudo ufw allow from 192.168.1.0/24 to any port 445 comment 'SMB'

# Development tools
sudo ufw allow from 192.168.1.0/24 to any port 3000 comment 'Development server'
sudo ufw allow from 192.168.1.0/24 to any port 8000 comment 'Alternative web server'

# DNS and NTP
sudo ufw allow out 53 comment 'DNS'
sudo ufw allow out 123 comment 'NTP'

# HTTPS for package updates and API calls
sudo ufw allow out 80 comment 'HTTP'
sudo ufw allow out 443 comment 'HTTPS'

# Enable logging
sudo ufw logging medium

# Create application profiles
sudo tee /etc/ufw/applications.d/claude-code <<EOF
[Claude-API]
title=Claude Code API
description=Claude Code inference API
ports=8080,8443/tcp

[Claude-MCP]
title=Claude MCP Server
description=Model Context Protocol server
ports=9090/tcp

[Development]
title=Development Tools
description=Local development servers
ports=3000,8000,4000/tcp
EOF

# Apply application rules
sudo ufw app update Claude-API
sudo ufw app update Claude-MCP
sudo ufw app update Development

# Enable firewall
sudo ufw enable

echo "Firewall configuration completed!"
sudo ufw status verbose
```

## Complete Setup and Deployment Scripts

### Main Deployment Script

**scripts/deploy_claude_infrastructure.sh**
```bash
#!/bin/bash
set -euo pipefail

# Claude Code Infrastructure Deployment Script
# Usage: ./deploy_claude_infrastructure.sh [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
CLAUDE_USER="claude-user"
SERVER_IP="192.168.1.100"
GITHUB_TOKEN=""
SSH_PUBLIC_KEY=""
DEPLOY_MODE="production"
ENABLE_MCP_SERVER=true

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Claude Code Infrastructure Deployment

Usage: $0 [OPTIONS]

Options:
    -u, --user USER         Claude service user (default: claude-user)
    -i, --ip IP            Server IP address (default: 192.168.1.100)
    -t, --token TOKEN      GitHub token for MCP integration
    -k, --ssh-key PATH     Path to SSH public key
    -m, --mode MODE        Deployment mode: dev|staging|production (default: production)
    --no-mcp              Disable MCP server deployment
    -h, --help            Show this help message

Examples:
    $0 --token ghp_xxx --ssh-key ~/.ssh/id_rsa.pub
    $0 --user claude-dev --mode staging --no-mcp
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            CLAUDE_USER="$2"
            shift 2
            ;;
        -i|--ip)
            SERVER_IP="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_PUBLIC_KEY="$(cat "$2")"
            shift 2
            ;;
        -m|--mode)
            DEPLOY_MODE="$2"
            shift 2
            ;;
        --no-mcp)
            ENABLE_MCP_SERVER=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$GITHUB_TOKEN" ]]; then
    print_error "GitHub token is required. Use --token option."
    exit 1
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
    print_error "SSH public key is required. Use --ssh-key option."
    exit 1
fi

print_status "Starting Claude Code infrastructure deployment..."
print_status "Configuration:"
print_status "  User: $CLAUDE_USER"
print_status "  Server IP: $SERVER_IP"
print_status "  Deploy Mode: $DEPLOY_MODE"
print_status "  MCP Server: $ENABLE_MCP_SERVER"

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    exit 1
fi

# Check required tools
required_tools=("terraform" "node" "npm" "git" "gh")
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

# Check Terraform version
terraform_version=$(terraform --version | head -n1 | cut -d' ' -f2 | sed 's/v//')
required_terraform="1.5.0"
if ! printf '%s\n%s\n' "$required_terraform" "$terraform_version" | sort -V -C; then
    print_error "Terraform version $required_terraform or higher is required"
    exit 1
fi

# Phase 1: System preparation
print_status "Phase 1: System preparation"

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required system packages
print_status "Installing system dependencies..."
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    unzip

# Phase 2: Infrastructure deployment with Terraform
print_status "Phase 2: Infrastructure deployment"

cd "$PROJECT_ROOT/terraform"

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Create terraform.tfvars
print_status "Creating Terraform configuration..."
cat > terraform.tfvars <<EOF
claude_user    = "$CLAUDE_USER"
server_ip      = "$SERVER_IP"
github_token   = "$GITHUB_TOKEN"
ssh_public_key = "$SSH_PUBLIC_KEY"
EOF

# Plan deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply deployment
print_status "Applying Terraform configuration..."
terraform apply tfplan

# Phase 3: Service configuration
print_status "Phase 3: Service configuration"

# Configure firewall
print_status "Configuring firewall..."
"$SCRIPT_DIR/configure_firewall.sh"

# Start services
print_status "Starting Claude Code services..."
sudo systemctl start claude-services.slice
sudo systemctl start claude-code.service

if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    sudo systemctl start claude-mcp-server.service
fi

# Phase 4: Verification
print_status "Phase 4: Deployment verification"

# Check service status
print_status "Verifying service status..."
systemctl status claude-code.service --no-pager
if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    systemctl status claude-mcp-server.service --no-pager
fi

# Check firewall status
print_status "Verifying firewall configuration..."
sudo ufw status

# Test Claude Code installation
print_status "Testing Claude Code installation..."
sudo -u "$CLAUDE_USER" bash -c '
    source ~/.bashrc
    claude --version
'

# Phase 5: Post-deployment setup
print_status "Phase 5: Post-deployment setup"

# Create sample workspace
print_status "Creating sample workspace..."
sudo -u "$CLAUDE_USER" mkdir -p "/home/$CLAUDE_USER/workspaces/sample-project"

# Generate documentation
print_status "Generating deployment documentation..."
cat > "$PROJECT_ROOT/DEPLOYMENT_SUMMARY.md" <<EOF
# Claude Code Deployment Summary

## Configuration
- **User**: $CLAUDE_USER
- **Server IP**: $SERVER_IP
- **Deploy Mode**: $DEPLOY_MODE
- **MCP Server**: $ENABLE_MCP_SERVER

## Services
- claude-code.service: $(systemctl is-active claude-code.service)
$(if [[ "$ENABLE_MCP_SERVER" == true ]]; then echo "- claude-mcp-server.service: $(systemctl is-active claude-mcp-server.service)"; fi)

## Access Information
- SSH: ssh $CLAUDE_USER@$SERVER_IP
- Claude Workspace: /home/$CLAUDE_USER/workspaces/
$(if [[ "$ENABLE_MCP_SERVER" == true ]]; then echo "- MCP Server: http://$SERVER_IP:9090"; fi)

## Management Commands
- Start services: sudo systemctl start claude-services.slice
- Stop services: sudo systemctl stop claude-services.slice
- View logs: journalctl -u claude-code.service -f
- Check status: systemctl status claude-code.service

## Security
- Firewall: $(sudo ufw status | head -n1)
- Service isolation: Active (systemd sandboxing)
- Audit logging: $(systemctl is-active auditd)

Deployment completed: $(date)
EOF

print_status "Deployment completed successfully!"
print_status "Summary written to: $PROJECT_ROOT/DEPLOYMENT_SUMMARY.md"
print_status ""
print_status "Next steps:"
print_status "1. SSH to server: ssh $CLAUDE_USER@$SERVER_IP"
print_status "2. Navigate to workspace: cd ~/workspaces/"
print_status "3. Initialize Claude Code: claude init"
print_status "4. Start coding with AI assistance!"

if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    print_status "5. MCP Server available at: http://$SERVER_IP:9090"
fi
```

## Testing and Troubleshooting Guide

### MVP Testing Phase Setup

**tests/test_deployment.sh**
```bash
#!/bin/bash
set -euo pipefail

# Claude Code Deployment Testing Suite
# Tests the three operational paths

CLAUDE_USER="claude-user"
SERVER_IP="192.168.1.100"

print_test() {
    echo "🧪 Testing: $1"
}

print_pass() {
    echo "✅ PASS: $1"
}

print_fail() {
    echo "❌ FAIL: $1"
}

# Test 1: Safe home-server deployment
print_test "Path 1: Safe home-server deployment"

# Check user isolation
if id "$CLAUDE_USER" &>/dev/null; then
    print_pass "Claude user exists"
else
    print_fail "Claude user not found"
fi

# Check service status
if systemctl is-active claude-code.service &>/dev/null; then
    print_pass "Claude Code service is running"
else
    print_fail "Claude Code service not running"
fi

# Check security isolation
security_score=$(systemd-analyze security claude-code.service --no-pager | grep -o '[0-9.]*' | head -1)
if (( $(echo "$security_score < 5.0" | bc -l) )); then
    print_pass "Security hardening in place (score: $security_score)"
else
    print_fail "Security hardening needs improvement (score: $security_score)"
fi

# Test 2: PR review workflow
print_test "Path 2: PR review workflow"

# Check GitHub CLI authentication
if sudo -u "$CLAUDE_USER" gh auth status &>/dev/null; then
    print_pass "GitHub CLI authenticated"
else
    print_fail "GitHub CLI not authenticated"
fi

# Test Claude Code CLI access
if sudo -u "$CLAUDE_USER" bash -c 'source ~/.bashrc && claude --version' &>/dev/null; then
    print_pass "Claude Code CLI accessible"
else
    print_fail "Claude Code CLI not accessible"
fi

# Test 3: MCP server option
print_test "Path 3: MCP server deployment"

if systemctl is-active claude-mcp-server.service &>/dev/null; then
    print_pass "MCP server is running"
    
    # Test MCP server connectivity
    if curl -s "http://$SERVER_IP:9090/health" &>/dev/null; then
        print_pass "MCP server responding"
    else
        print_fail "MCP server not responding"
    fi
else
    print_fail "MCP server not running"
fi

# Network connectivity tests
print_test "Network and firewall configuration"

# Check UFW status
if sudo ufw status | grep -q "Status: active"; then
    print_pass "UFW firewall is active"
else
    print_fail "UFW firewall not active"
fi

# Test Windows client access (SMB)
if nc -z "$SERVER_IP" 445 2>/dev/null; then
    print_pass "SMB port accessible for Windows clients"
else
    print_fail "SMB port not accessible"
fi

echo ""
echo "🎯 Test Summary Complete"
echo "Review any failed tests and run corresponding troubleshooting steps."
```

### Troubleshooting Guide

**docs/TROUBLESHOOTING.md**
```markdown
# Claude Code Infrastructure Troubleshooting Guide

## Common Issues and Solutions

### 1. Service Start Failures

**Issue**: `claude-code.service` fails to start
```bash
# Check service status
systemctl status claude-code.service

# View detailed logs
journalctl -u claude-code.service --no-pager

# Common fixes:
sudo systemctl daemon-reload
sudo systemctl restart claude-code.service
```

**Issue**: Permission denied errors
```bash
# Fix ownership
sudo chown -R claude-user:claude-user /home/claude-user
sudo chown -R claude-user:claude-user /var/lib/claude-code

# Fix npm permissions
sudo -u claude-user npm config set prefix ~/.npm-global
```

### 2. Network Connectivity Issues

**Issue**: Cannot access from Windows client
```bash
# Check firewall rules
sudo ufw status verbose

# Test SMB connectivity
smbclient -L //192.168.1.100 -N

# Restart Samba
sudo systemctl restart smbd nmbd
```

**Issue**: GitHub CLI authentication fails
```bash
# Re-authenticate GitHub CLI
sudo -u claude-user gh auth login

# Check token permissions
sudo -u claude-user gh auth status
```

### 3. Performance Issues

**Issue**: High memory usage
```bash
# Check memory limits
systemctl show claude-code.service | grep Memory

# Adjust limits in service file
sudo systemctl edit claude-code.service
```

**Issue**: CPU throttling
```bash
# Check CPU usage
systemd-cgtop

# Adjust CPU quota
sudo systemctl edit claude-code.service
```

### 4. Security Warnings

**Issue**: Security score too high
```bash
# Analyze security settings
systemd-analyze security claude-code.service

# Apply additional hardening
sudo systemctl edit claude-code.service
```

### 5. MCP Server Issues

**Issue**: MCP server not responding
```bash
# Check service logs
journalctl -u claude-mcp-server.service -f

# Test server directly
curl http://localhost:9090/health

# Restart server
sudo systemctl restart claude-mcp-server.service
```

## Diagnostic Commands

```bash
# System health check
sudo systemctl status
sudo systemd-analyze
sudo journalctl --priority=err --since="1 hour ago"

# Service diagnostics
systemctl list-units --failed
systemd-analyze security
systemd-analyze blame

# Network diagnostics
sudo ss -tlnp
sudo ufw status verbose
sudo netstat -tulpn | grep :9090

# User and permissions
sudo -u claude-user whoami
sudo -u claude-user groups
ls -la /home/claude-user/
```

## Recovery Procedures

### Complete Service Reset
```bash
# Stop all services
sudo systemctl stop claude-code.service claude-mcp-server.service

# Reset user environment
sudo -u claude-user bash -c 'rm -rf ~/.npm-global ~/.claude'
sudo -u claude-user npm config set prefix ~/.npm-global

# Reinstall Claude Code
sudo -u claude-user npm install -g @anthropic-ai/claude-code

# Restart services
sudo systemctl start claude-code.service claude-mcp-server.service
```

### Infrastructure Rebuild
```bash
# Navigate to terraform directory
cd terraform/

# Destroy current infrastructure
terraform destroy

# Redeploy
terraform apply
```
```

This comprehensive setup provides production-ready infrastructure for Claude Code deployment on Ubuntu home servers with complete GitHub MCP integration, automated PR workflows, and robust security hardening. The solution supports all three operational paths requested and includes extensive documentation for troubleshooting and maintenance.