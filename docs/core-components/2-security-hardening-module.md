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