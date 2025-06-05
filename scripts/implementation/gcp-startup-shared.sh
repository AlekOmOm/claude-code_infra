#!/bin/bash
# GCP startup script for shared Claude Code instance

set -euo pipefail

# Update system
apt update && apt upgrade -y

# Install base dependencies
apt install -y curl wget git build-essential software-properties-common

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install Docker for containerized workspaces
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Configure firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from 10.0.0.0/8 to any port 8080
ufw allow from 10.0.0.0/8 to any port 8443
ufw allow from 10.0.0.0/8 to any port 9090
ufw --force enable

# Create claude-user if it doesn't exist
if ! id claude-user &>/dev/null; then
    useradd -r -m -s /bin/bash -c "Claude Code Service User" claude-user
    usermod -a -G docker claude-user
fi

# Set up npm global directory
sudo -u claude-user bash -c "
    npm config set prefix ~/.npm-global
    echo 'export PATH=~/.npm-global/bin:\$PATH' >> ~/.bashrc
"

# Install Claude Code
sudo -u claude-user npm install -g @anthropic-ai/claude-code

# Create workspace structure
sudo -u claude-user mkdir -p /home/claude-user/workspaces

# Log startup completion
echo "$(date): Claude Code shared instance setup completed" >> /var/log/gcp-startup.log
