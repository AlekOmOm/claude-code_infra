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