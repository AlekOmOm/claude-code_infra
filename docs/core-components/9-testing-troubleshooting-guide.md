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