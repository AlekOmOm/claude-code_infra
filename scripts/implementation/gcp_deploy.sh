#!/bin/bash
# scripts/implementation/gcp_deploy.sh
# Google Cloud Platform deployment script for Claude Code

set -euo pipefail

# Load utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env_utils.sh"
source "$SCRIPT_DIR/gcloud_utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[GCP-DEPLOY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[GCP-WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[GCP-ERROR]${NC} $1"
}

# Main GCP deployment function
gcp_deploy_claude_infrastructure() {
    print_status "Starting Google Cloud Platform deployment for Claude Code..."
    
    # Verify GCP configuration
    verify_gcp_configuration
    
    # Check prerequisites
    if ! gcp_check_prerequisites; then
        print_error "GCP prerequisites not met"
        return 1
    fi
    
    # Load configuration
    local project=$(get_env_value "GOOGLE_CLOUD_PROJECT")
    local region=$(get_env_value "GOOGLE_CLOUD_REGION")
    local zone=$(get_env_value "GOOGLE_CLOUD_ZONE")
    local strategy=$(get_env_value "GCP_INSTANCE_STRATEGY" "shared")
    local machine_type=$(get_env_value "GCP_MACHINE_TYPE" "e2-medium")
    local use_existing=$(get_env_value "GCP_USE_EXISTING_INSTANCE" "false")
    
    print_status "Configuration:"
    print_status "  Project: $project"
    print_status "  Region: $region"
    print_status "  Zone: $zone"
    print_status "  Strategy: $strategy"
    print_status "  Machine Type: $machine_type"
    
    # Enable required APIs
    gcp_enable_apis
    
    # Create or use existing instance
    if [[ "$use_existing" == "true" ]]; then
        local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
        local instance_zone=$(get_env_value "GCP_INSTANCE_ZONE")
        
        if [[ -n "$instance_name" && -n "$instance_zone" ]]; then
            print_status "Using existing instance: $instance_name"
            
            # Check if instance is running
            local status=$(gcp_get_instance_status "$instance_name" "$instance_zone")
            if [[ "$status" != "RUNNING" ]]; then
                print_status "Starting existing instance..."
                gcp_start_instance "$instance_name" "$instance_zone"
            fi
        else
            print_warning "Existing instance configured but details missing, creating new instance"
            create_new_instance "$strategy" "$machine_type"
        fi
    else
        create_new_instance "$strategy" "$machine_type"
    fi
    
    # Wait for instance to be ready
    wait_for_instance_ready
    
    # Configure SSH access
    setup_ssh_access
    
    # Run post-deployment configuration
    run_post_deployment_setup
    
    print_status "GCP deployment completed successfully!"
    
    # Display connection information
    display_connection_info
}

# Verify GCP configuration is complete
verify_gcp_configuration() {
    print_status "Verifying GCP configuration..."
    
    local required_vars=(
        "GOOGLE_CLOUD_PROJECT"
        "GOOGLE_CLOUD_REGION"
        "GOOGLE_CLOUD_ZONE"
        "GCP_INSTANCE_STRATEGY"
        "GCP_MACHINE_TYPE"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        local value=$(get_env_value "$var")
        if [[ -z "$value" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required GCP configuration variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        print_error "Please run: ./scripts/phases/0_infrastructure_choice.sh"
        return 1
    fi
    
    print_status "GCP configuration verified"
}

# Create new instance
create_new_instance() {
    local strategy="$1"
    local machine_type="$2"
    
    print_status "Creating new Claude Code instance..."
    
    # Generate unique instance name
    local instance_name="claude-code-$(date +%Y%m%d-%H%M%S)"
    
    # Create startup scripts if they don't exist
    gcp_create_startup_scripts
    
    # Create the instance
    if gcp_create_claude_instance "$instance_name" "$machine_type" "$strategy"; then
        print_status "Instance created successfully: $instance_name"
    else
        print_error "Failed to create instance"
        return 1
    fi
}

# Wait for instance to be ready
wait_for_instance_ready() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for instance to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local status=$(gcp_get_instance_status "$instance_name" "$zone")
        
        if [[ "$status" == "RUNNING" ]]; then
            print_status "Instance is running"
            break
        fi
        
        print_status "Instance status: $status (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        print_error "Instance failed to start within expected time"
        return 1
    fi
    
    # Wait additional time for startup script to complete
    print_status "Waiting for startup script to complete..."
    sleep 60
}

# Setup SSH access to the instance
setup_ssh_access() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    local claude_user=$(get_env_value "CLAUDE_USER_NAME" "claude-user")
    
    print_status "Setting up SSH access..."
    
    # Add SSH key to instance metadata
    local ssh_key_path=$(get_env_value "SSH_PUBLIC_KEY_PATH")
    if [[ -f "$ssh_key_path" ]]; then
        local ssh_key_content=$(cat "$ssh_key_path")
        
        # Add SSH key to instance
        gcloud compute instances add-metadata "$instance_name" \
            --zone="$zone" \
            --metadata="ssh-keys=${claude_user}:${ssh_key_content}"
        
        print_status "SSH key added to instance"
    else
        print_warning "SSH key file not found at: $ssh_key_path"
        print_warning "You may need to use gcloud compute ssh for access"
    fi
}

# Run post-deployment setup
run_post_deployment_setup() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    local claude_user=$(get_env_value "CLAUDE_USER_NAME" "claude-user")
    local github_token=$(get_env_value "GITHUB_PAT")
    
    print_status "Running post-deployment setup..."
    
    # Create a temporary setup script
    local setup_script="/tmp/gcp-post-setup.sh"
    cat > "$setup_script" << EOF
#!/bin/bash
set -euo pipefail

# Configure GitHub CLI authentication
if [[ -n "$github_token" ]]; then
    sudo -u $claude_user bash -c "echo '$github_token' | gh auth login --with-token"
    sudo -u $claude_user gh auth status
fi

# Create sample workspace if it doesn't exist
sudo -u $claude_user mkdir -p /home/$claude_user/workspaces/sample-project

# Verify Claude Code installation
if sudo -u $claude_user bash -c 'source ~/.bashrc && which claude' &>/dev/null; then
    echo "Claude Code installation verified"
    sudo -u $claude_user bash -c 'source ~/.bashrc && claude --version'
else
    echo "Claude Code not found, attempting installation..."
    sudo -u $claude_user npm install -g @anthropic-ai/claude-code
fi

# Set up systemd service for Claude Code
cat > /etc/systemd/system/claude-code.service << 'SYSTEMD_EOF'
[Unit]
Description=Claude Code Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$claude_user
Group=$claude_user
WorkingDirectory=/home/$claude_user/workspaces
Environment="NODE_ENV=production"
Environment="PATH=/home/$claude_user/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/$claude_user/.npm-global/bin/claude
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

systemctl daemon-reload
systemctl enable claude-code.service

echo "Post-deployment setup completed"
EOF

    # Copy and execute the setup script on the instance
    gcloud compute scp "$setup_script" "$instance_name:/tmp/post-setup.sh" --zone="$zone"
    gcloud compute ssh "$instance_name" --zone="$zone" --command="sudo chmod +x /tmp/post-setup.sh && sudo /tmp/post-setup.sh"
    
    # Clean up
    rm -f "$setup_script"
    
    print_status "Post-deployment setup completed"
}

# Display connection information
display_connection_info() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    local instance_ip=$(get_env_value "TARGET_SERVER_IP")
    local claude_user=$(get_env_value "CLAUDE_USER_NAME" "claude-user")
    local project=$(get_env_value "GOOGLE_CLOUD_PROJECT")
    
    print_status ""
    print_status "🎉 Claude Code GCP Deployment Complete!"
    print_status "========================================="
    print_status ""
    print_status "Instance Details:"
    print_status "  Name: $instance_name"
    print_status "  Zone: $zone"
    print_status "  IP: $instance_ip"
    print_status "  Project: $project"
    print_status ""
    print_status "Connection Options:"
    print_status "  SSH (direct): ssh $claude_user@$instance_ip"
    print_status "  SSH (gcloud): gcloud compute ssh $claude_user@$instance_name --zone=$zone"
    print_status ""
    print_status "Management Commands:"
    print_status "  Start instance: gcloud compute instances start $instance_name --zone=$zone"
    print_status "  Stop instance: gcloud compute instances stop $instance_name --zone=$zone"
    print_status "  View logs: gcloud compute ssh $instance_name --zone=$zone --command='journalctl -u claude-code.service -f'"
    print_status ""
    print_status "Cost Management:"
    print_status "  Stop instance when not in use to save costs"
    print_status "  Estimated monthly cost: \$15-25 (when running continuously)"
    print_status ""
    print_status "Next Steps:"
    print_status "  1. SSH to the instance using one of the methods above"
    print_status "  2. Navigate to: cd ~/workspaces/sample-project"
    print_status "  3. Start Claude Code: claude"
}

# Quick instance management functions
gcp_quick_start() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        print_error "No GCP instance configured. Run deployment first."
        return 1
    fi
    
    print_status "Starting Claude Code instance..."
    gcp_start_instance "$instance_name" "$zone"
}

gcp_quick_stop() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        print_error "No GCP instance configured."
        return 1
    fi
    
    print_status "Stopping Claude Code instance..."
    gcp_stop_instance "$instance_name" "$zone"
}

gcp_quick_connect() {
    local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
    local zone=$(get_env_value "GCP_INSTANCE_ZONE")
    local claude_user=$(get_env_value "CLAUDE_USER_NAME" "claude-user")
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        print_error "No GCP instance configured."
        return 1
    fi
    
    # Check if instance is running
    local status=$(gcp_get_instance_status "$instance_name" "$zone")
    if [[ "$status" != "RUNNING" ]]; then
        print_status "Instance is not running. Starting..."
        gcp_start_instance "$instance_name" "$zone"
        sleep 30
    fi
    
    print_status "Connecting to Claude Code instance..."
    gcp_ssh_instance "$instance_name" "$zone" "$claude_user"
}

# Command line interface for this script
case "${1:-deploy}" in
    "deploy")
        gcp_deploy_claude_infrastructure
        ;;
    "start")
        gcp_quick_start
        ;;
    "stop")
        gcp_quick_stop
        ;;
    "connect")
        gcp_quick_connect
        ;;
    "status")
        local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
        local zone=$(get_env_value "GCP_INSTANCE_ZONE")
        if [[ -n "$instance_name" && -n "$zone" ]]; then
            local status=$(gcp_get_instance_status "$instance_name" "$zone")
            echo "Instance $instance_name status: $status"
        else
            echo "No GCP instance configured"
        fi
        ;;
    "list")
        gcp_list_claude_instances
        ;;
    "costs")
        gcp_estimate_costs
        ;;
    *)
        echo "Usage: $0 {deploy|start|stop|connect|status|list|costs}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy Claude Code to GCP"
        echo "  start    - Start the GCP instance"
        echo "  stop     - Stop the GCP instance"
        echo "  connect  - SSH to the GCP instance"
        echo "  status   - Show instance status"
        echo "  list     - List all Claude Code instances"
        echo "  costs    - Show cost estimates"
        exit 1
        ;;
esac
