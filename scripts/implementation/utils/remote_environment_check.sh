#!/bin/bash
# Utility functions for checking remote environment health

# Source env utils if not already sourced
if ! declare -f get_env_value >/dev/null; then
    source "$(dirname "$0")/../env_utils.sh"
fi

# Check overall remote environment health
# Returns: "healthy", "degraded", or "unhealthy"
check_remote_environment() {
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    local enable_mcp=$(get_env_value "ENABLE_MCP_SERVER" "true")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    local health_score=0
    local max_score=7
    
    # Adjust max score if MCP is disabled
    if [ "$enable_mcp" != "true" ]; then
        ((max_score--))
    fi
    
    # 1. Check SSH connectivity
    if ssh $ssh_opts "${claude_user}@${server_ip}" "exit" 2>/dev/null; then
        ((health_score++))
    else
        echo "unhealthy"
        return
    fi
    
    # 2. Check Claude Code service is active
    if ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active claude-code.service" 2>/dev/null | grep -q "active"; then
        ((health_score++))
    fi
    
    # 3. Check MCP server service if enabled
    if [ "$enable_mcp" = "true" ]; then
        if ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active claude-mcp-server.service" 2>/dev/null | grep -q "active"; then
            ((health_score++))
        fi
    fi
    
    # 4. Check system resources (memory)
    local mem_free=$(ssh $ssh_opts "${claude_user}@${server_ip}" "free -m | awk '/^Mem:/ {print int(\$7/\$2*100)}'" 2>/dev/null || echo "0")
    if [ "$mem_free" -gt 20 ]; then
        ((health_score++))
    fi
    
    # 5. Check disk space
    local disk_free=$(ssh $ssh_opts "${claude_user}@${server_ip}" "df -h /home | awk 'NR==2 {print 100-\$5}' | tr -d '%'" 2>/dev/null || echo "0")
    if [ "$disk_free" -gt 20 ]; then
        ((health_score++))
    fi
    
    # 6. Check Claude CLI is accessible
    if ssh $ssh_opts "${claude_user}@${server_ip}" "source ~/.bashrc && which claude" 2>/dev/null; then
        ((health_score++))
    fi
    
    # 7. Check firewall is active
    if ssh $ssh_opts "${claude_user}@${server_ip}" "sudo ufw status 2>/dev/null | grep -q 'Status: active'" 2>/dev/null; then
        ((health_score++))
    fi
    
    # Determine health status
    local health_percentage=$((health_score * 100 / max_score))
    
    if [ $health_percentage -ge 90 ]; then
        echo "healthy"
    elif [ $health_percentage -ge 60 ]; then
        echo "degraded"
    else
        echo "unhealthy"
    fi
}

# Get detailed health status
get_health_details() {
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    local enable_mcp=$(get_env_value "ENABLE_MCP_SERVER" "true")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    echo "Remote Environment Health Check"
    echo "==============================="
    echo ""
    echo "Server: $server_ip"
    echo "User: $claude_user"
    echo ""
    
    # SSH Connectivity
    echo -n "SSH Connectivity: "
    if ssh $ssh_opts "${claude_user}@${server_ip}" "exit" 2>/dev/null; then
        echo "✓ Connected"
    else
        echo "✗ Failed"
        return 1
    fi
    
    # Service Status
    echo ""
    echo "Services:"
    echo -n "  claude-code.service: "
    local claude_status=$(ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active claude-code.service 2>/dev/null" 2>/dev/null || echo "unknown")
    case "$claude_status" in
        "active")
            echo "✓ Active"
            ;;
        "inactive")
            echo "✗ Inactive"
            ;;
        "failed")
            echo "✗ Failed"
            ;;
        *)
            echo "? Unknown"
            ;;
    esac
    
    if [ "$enable_mcp" = "true" ]; then
        echo -n "  claude-mcp-server.service: "
        local mcp_status=$(ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active claude-mcp-server.service 2>/dev/null" 2>/dev/null || echo "unknown")
        case "$mcp_status" in
            "active")
                echo "✓ Active"
                ;;
            "inactive")
                echo "✗ Inactive"
                ;;
            "failed")
                echo "✗ Failed"
                ;;
            *)
                echo "? Unknown"
                ;;
        esac
    fi
    
    # System Resources
    echo ""
    echo "System Resources:"
    
    # Memory
    echo -n "  Memory: "
    local mem_info=$(ssh $ssh_opts "${claude_user}@${server_ip}" "free -h | awk '/^Mem:/ {print \"Used: \" \$3 \"/\" \$2 \" (\" int(\$3/\$2*100) \"%)\" }'" 2>/dev/null || echo "Unknown")
    echo "$mem_info"
    
    # Disk
    echo -n "  Disk (/home): "
    local disk_info=$(ssh $ssh_opts "${claude_user}@${server_ip}" "df -h /home | awk 'NR==2 {print \"Used: \" \$3 \"/\" \$2 \" (\" \$5 \")\" }'" 2>/dev/null || echo "Unknown")
    echo "$disk_info"
    
    # CPU Load
    echo -n "  CPU Load: "
    local load_info=$(ssh $ssh_opts "${claude_user}@${server_ip}" "uptime | awk -F'load average:' '{print \$2}'" 2>/dev/null || echo "Unknown")
    echo "$load_info"
    
    # Network
    echo ""
    echo "Network:"
    echo -n "  Firewall: "
    if ssh $ssh_opts "${claude_user}@${server_ip}" "sudo ufw status 2>/dev/null | grep -q 'Status: active'" 2>/dev/null; then
        echo "✓ Active"
    else
        echo "✗ Inactive or not accessible"
    fi
    
    # Claude Environment
    echo ""
    echo "Claude Environment:"
    echo -n "  Claude CLI: "
    if ssh $ssh_opts "${claude_user}@${server_ip}" "source ~/.bashrc && which claude" 2>/dev/null >/dev/null; then
        echo "✓ Available"
        local claude_version=$(ssh $ssh_opts "${claude_user}@${server_ip}" "source ~/.bashrc && claude --version 2>/dev/null" 2>/dev/null || echo "Unknown")
        echo "  Version: $claude_version"
    else
        echo "✗ Not found"
    fi
    
    echo -n "  Workspaces Directory: "
    if ssh $ssh_opts "${claude_user}@${server_ip}" "test -d ~/workspaces" 2>/dev/null; then
        echo "✓ Exists"
        local project_count=$(ssh $ssh_opts "${claude_user}@${server_ip}" "find ~/workspaces -mindepth 1 -maxdepth 1 -type d | wc -l" 2>/dev/null || echo "0")
        echo "  Projects: $project_count"
    else
        echo "✗ Not found"
    fi
}

# Check specific service health
check_service_health() {
    local service_name="$1"
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    # Get service details
    local status=$(ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active $service_name 2>/dev/null" 2>/dev/null || echo "unknown")
    local enabled=$(ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-enabled $service_name 2>/dev/null" 2>/dev/null || echo "unknown")
    
    echo "Service: $service_name"
    echo "  Status: $status"
    echo "  Enabled: $enabled"
    
    if [ "$status" = "active" ]; then
        # Get recent logs
        echo "  Recent logs:"
        ssh $ssh_opts "${claude_user}@${server_ip}" "journalctl -u $service_name -n 5 --no-pager 2>/dev/null" 2>/dev/null | sed 's/^/    /'
    fi
}

# Get resource usage for Claude services
get_claude_resource_usage() {
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    echo "Claude Services Resource Usage"
    echo "=============================="
    
    # Get systemd-cgtop output for claude services
    ssh $ssh_opts "${claude_user}@${server_ip}" "sudo systemd-cgtop -n 1 --raw | grep -E 'claude|slice'" 2>/dev/null || echo "Unable to retrieve resource usage"
}

# Self-test when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running remote environment health check..."
    echo ""
    
    # Check overall health
    health=$(check_remote_environment)
    echo "Overall Health: $health"
    echo ""
    
    # Show detailed health information
    get_health_details
    echo ""
    
    # Check specific service
    echo "Checking claude-code service specifically:"
    check_service_health "claude-code.service"
fi