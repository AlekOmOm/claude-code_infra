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