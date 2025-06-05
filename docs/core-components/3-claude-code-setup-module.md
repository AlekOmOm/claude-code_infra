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