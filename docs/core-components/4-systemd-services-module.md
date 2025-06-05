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