#!/bin/bash
# Utility functions for checking deployment status

# Source env utils if not already sourced
if ! declare -f get_env_value >/dev/null; then
    source "$(dirname "$0")/../env_utils.sh"
fi

# Check if Claude Code is deployed on the target server
# Returns: "deployed", "partial", or "not_deployed"
check_deployment_status() {
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    
    if [ -z "$server_ip" ] || [ "$server_ip" = "YOUR_SERVER_IP_HERE" ]; then
        echo "not_deployed"
        return
    fi
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    # Check if we can SSH to the server
    if ! ssh $ssh_opts "${claude_user}@${server_ip}" "exit" 2>/dev/null; then
        # Try with default user
        if ! ssh $ssh_opts "ubuntu@${server_ip}" "exit" 2>/dev/null; then
            echo "not_deployed"
            return
        fi
    fi
    
    # Check for key deployment indicators
    local deployment_score=0
    local max_score=5
    
    # Check if claude user exists
    if ssh $ssh_opts "${claude_user}@${server_ip}" "id" 2>/dev/null; then
        ((deployment_score++))
    fi
    
    # Check if Claude Code is installed
    if ssh $ssh_opts "${claude_user}@${server_ip}" "which claude" 2>/dev/null; then
        ((deployment_score++))
    fi
    
    # Check if systemd service exists
    if ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl list-unit-files | grep claude-code.service" 2>/dev/null; then
        ((deployment_score++))
    fi
    
    # Check if workspaces directory exists
    if ssh $ssh_opts "${claude_user}@${server_ip}" "test -d ~/workspaces" 2>/dev/null; then
        ((deployment_score++))
    fi
    
    # Check if Node.js is installed
    if ssh $ssh_opts "${claude_user}@${server_ip}" "which node" 2>/dev/null; then
        ((deployment_score++))
    fi
    
    # Determine deployment status based on score
    if [ $deployment_score -eq $max_score ]; then
        echo "deployed"
    elif [ $deployment_score -gt 0 ]; then
        echo "partial"
    else
        echo "not_deployed"
    fi
}

# Check if specific components are deployed
check_component_status() {
    local component="$1"
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    case "$component" in
        "claude-user")
            ssh $ssh_opts "${claude_user}@${server_ip}" "id" 2>/dev/null
            ;;
        "claude-code")
            ssh $ssh_opts "${claude_user}@${server_ip}" "which claude" 2>/dev/null
            ;;
        "systemd-service")
            ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl list-unit-files | grep claude-code.service" 2>/dev/null
            ;;
        "mcp-server")
            local enable_mcp=$(get_env_value "ENABLE_MCP_SERVER" "true")
            if [ "$enable_mcp" = "true" ]; then
                ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl list-unit-files | grep claude-mcp-server.service" 2>/dev/null
            else
                return 0 # Not expected, so return success
            fi
            ;;
        "nodejs")
            ssh $ssh_opts "${claude_user}@${server_ip}" "which node" 2>/dev/null
            ;;
        "github-cli")
            ssh $ssh_opts "${claude_user}@${server_ip}" "which gh" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Get detailed deployment information
get_deployment_details() {
    local server_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER" "claude-user")
    local ssh_key_path=$(get_env_value "SSH_KEY_PATH")
    
    # Prepare SSH options
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$ssh_key_path" ] && [ -f "$ssh_key_path" ]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi
    
    echo "Deployment Details for $server_ip:"
    echo "================================="
    
    # Check each component
    local components=("claude-user" "claude-code" "systemd-service" "mcp-server" "nodejs" "github-cli")
    for comp in "${components[@]}"; do
        if check_component_status "$comp"; then
            echo "✓ $comp: Installed"
        else
            echo "✗ $comp: Not found"
        fi
    done
    
    # Get Claude version if available
    local claude_version=$(ssh $ssh_opts "${claude_user}@${server_ip}" "claude --version 2>/dev/null" 2>/dev/null || echo "Not installed")
    echo ""
    echo "Claude Code Version: $claude_version"
    
    # Get service status if available
    local service_status=$(ssh $ssh_opts "${claude_user}@${server_ip}" "systemctl is-active claude-code.service 2>/dev/null" 2>/dev/null || echo "Service not found")
    echo "Service Status: $service_status"
}

# Check if deployment configuration file exists
check_deployment_summary() {
    local summary_file="DEPLOYMENT_SUMMARY.md"
    
    if [ -f "$summary_file" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Self-test when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running deployment check utilities tests..."
    echo ""
    
    # Test deployment status
    status=$(check_deployment_status)
    echo "Deployment Status: $status"
    echo ""
    
    # Show detailed information
    get_deployment_details
fi