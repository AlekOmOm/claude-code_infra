#!/bin/bash
# scripts/implementation/gcloud_utils.sh
# Utilities for Google Cloud Platform instance management

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# Load environment utilities
if [[ ! -f "./scripts/implementation/env_utils.sh" ]]; then
    echo "ERROR: env_utils.sh not found"
    return 1
fi
source "./scripts/implementation/env_utils.sh"

# Global configuration
GCP_DEFAULT_MACHINE_TYPE="e2-medium"
GCP_DEFAULT_DISK_SIZE="20GB"
GCP_DEFAULT_IMAGE_FAMILY="debian-12"
GCP_DEFAULT_IMAGE_PROJECT="debian-cloud"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

gcp_log() {
    echo -e "${GREEN}[GCP]${NC} $1"
}

gcp_warn() {
    echo -e "${YELLOW}[GCP-WARN]${NC} $1"
}

gcp_error() {
    echo -e "${RED}[GCP-ERROR]${NC} $1"
}

# Check if gcloud is installed and authenticated
gcp_check_prerequisites() {
    if ! command -v gcloud &> /dev/null; then
        gcp_error "Google Cloud CLI not found"
        echo "Install from: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
    
    if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | head -1 | grep -q "@"; then
        gcp_error "Not authenticated with Google Cloud"
        echo "Run: gcloud auth login"
        return 1
    fi
    
    local project=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project" ]]; then
        gcp_error "No project configured"
        echo "Run: gcloud config set project PROJECT_ID"
        return 1
    fi
    
    return 0
}

# Create a new Claude Code instance
gcp_create_claude_instance() {
    local instance_name="${1:-claude-code-$(date +%Y%m%d-%H%M%S)}"
    local machine_type="${2:-$GCP_DEFAULT_MACHINE_TYPE}"
    local strategy="${3:-shared}"
    
    local project=$(get_env_value "GOOGLE_CLOUD_PROJECT")
    local zone=$(get_env_value "GOOGLE_CLOUD_ZONE" "europe-north2-a")
    local region=$(get_env_value "GOOGLE_CLOUD_REGION" "europe-north2")
    
    gcp_log "Creating Claude Code instance: $instance_name"
    
    # Create VPC network if it doesn't exist
    gcp_ensure_network
    
    # Create firewall rules for Claude Code
    gcp_create_firewall_rules
    
    # Create the instance
    gcp_log "Creating compute instance..."
    
    local startup_script
    if [[ "$strategy" == "shared" ]]; then
        startup_script="./scripts/implementation/gcp-startup-shared.sh"
    else
        startup_script="./scripts/implementation/gcp-startup-dedicated.sh"
    fi
    
    gcloud compute instances create "$instance_name" \
        --zone="$zone" \
        --machine-type="$machine_type" \
        --image-family="$GCP_DEFAULT_IMAGE_FAMILY" \
        --image-project="$GCP_DEFAULT_IMAGE_PROJECT" \
        --boot-disk-size="$GCP_DEFAULT_DISK_SIZE" \
        --boot-disk-type="pd-standard" \
        --network="claude-vpc" \
        --subnet="claude-subnet" \
        --tags="claude-ssh,claude-code-server,claude-code-mgmt" \
        --labels="claude-code=true,environment=dev,strategy=$strategy" \
        --metadata-from-file="startup-script=$startup_script" \
        --metadata="enable-oslogin=TRUE,claude-strategy=$strategy" \
        --scopes="https://www.googleapis.com/auth/cloud-platform" \
        --maintenance-policy="MIGRATE" \
        --provisioning-model="STANDARD"
    
    if [[ $? -eq 0 ]]; then
        gcp_log "Instance created successfully: $instance_name"
        
        # Save instance details to .env
        update_env_value "GCP_INSTANCE_NAME" "$instance_name"
        update_env_value "GCP_INSTANCE_ZONE" "$zone"
        update_env_value "GCP_USE_EXISTING_INSTANCE" "true"
        
        # Wait for instance to be ready and get IP
        gcp_log "Waiting for instance to start..."
        sleep 30
        
        local instance_ip=$(gcloud compute instances describe "$instance_name" \
            --zone="$zone" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
        
        if [[ -n "$instance_ip" ]]; then
            update_env_value "TARGET_SERVER_IP" "$instance_ip"
            gcp_log "Instance IP: $instance_ip"
        fi
        
        # Setup snapshot schedule
        gcp_create_backup_schedule "$instance_name" "$zone"
        
        return 0
    else
        gcp_error "Failed to create instance"
        return 1
    fi
}

# Ensure Claude VPC network exists
gcp_ensure_network() {
    local region=$(get_env_value "GOOGLE_CLOUD_REGION" "europe-north2")
    
    # Check if VPC exists
    if ! gcloud compute networks describe claude-vpc &>/dev/null; then
        gcp_log "Creating Claude VPC network..."
        
        gcloud compute networks create claude-vpc \
            --subnet-mode=custom \
            --description="VPC for Claude Code instances"
        
        gcloud compute networks subnets create claude-subnet \
            --network=claude-vpc \
            --range=10.0.0.0/24 \
            --region="$region" \
            --description="Subnet for Claude Code instances"
    else
        gcp_log "Claude VPC network already exists"
    fi
}

# Create firewall rules for Claude Code
gcp_create_firewall_rules() {
    gcp_log "Creating firewall rules for Claude Code..."
    
    # SSH access
    gcloud compute firewall-rules create claude-ssh \
        --description="Allow SSH to Claude Code instances" \
        --direction=INGRESS \
        --priority=1000 \
        --network=claude-vpc \
        --action=ALLOW \
        --rules=tcp:22 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=claude-ssh \
        || gcp_warn "SSH firewall rule already exists"
    
    # Claude Code HTTP service
    gcloud compute firewall-rules create claude-code-http \
        --description="Allow Claude Code HTTP traffic" \
        --direction=INGRESS \
        --priority=1000 \
        --network=claude-vpc \
        --action=ALLOW \
        --rules=tcp:8080 \
        --source-ranges=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
        --target-tags=claude-code-server \
        || gcp_warn "HTTP firewall rule already exists"
    
    # Claude Code HTTPS service
    gcloud compute firewall-rules create claude-code-https \
        --description="Allow Claude Code HTTPS traffic" \
        --direction=INGRESS \
        --priority=1000 \
        --network=claude-vpc \
        --action=ALLOW \
        --rules=tcp:8443 \
        --source-ranges=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
        --target-tags=claude-code-server \
        || gcp_warn "HTTPS firewall rule already exists"
    
    # Claude Code management
    gcloud compute firewall-rules create claude-code-mgmt \
        --description="Allow Claude Code management traffic" \
        --direction=INGRESS \
        --priority=1000 \
        --network=claude-vpc \
        --action=ALLOW \
        --rules=tcp:9090 \
        --source-ranges=10.0.0.0/8 \
        --target-tags=claude-code-mgmt \
        || gcp_warn "Management firewall rule already exists"
}

# Create backup schedule for instance
gcp_create_backup_schedule() {
    local instance_name="$1"
    local zone="$2"
    local region=$(get_env_value "GOOGLE_CLOUD_REGION" "europe-north2")
    
    gcp_log "Setting up backup schedule for $instance_name..."
    
    # Create snapshot schedule
    gcloud compute resource-policies create snapshot-schedule claude-backup-schedule \
        --description="14-day backup schedule for Claude Code instances" \
        --max-retention-days=14 \
        --start-time=02:00 \
        --daily-schedule \
        --region="$region" \
        --snapshot-labels="env=dev,automated=true" \
        --storage-location=EU \
        || gcp_warn "Backup schedule already exists"
    
    # Apply schedule to instance disk
    local disk_name="$instance_name"
    gcloud compute disks add-resource-policies "$disk_name" \
        --resource-policies=claude-backup-schedule \
        --zone="$zone" \
        || gcp_warn "Failed to apply backup schedule to disk"
}

# Start an instance
gcp_start_instance() {
    local instance_name="${1:-$(get_env_value 'GCP_INSTANCE_NAME')}"
    local zone="${2:-$(get_env_value 'GCP_INSTANCE_ZONE')}"
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        gcp_error "Instance name or zone not specified"
        return 1
    fi
    
    gcp_log "Starting instance: $instance_name"
    
    gcloud compute instances start "$instance_name" --zone="$zone"
    
    if [[ $? -eq 0 ]]; then
        gcp_log "Instance started successfully"
        
        # Update IP address in case it changed
        local instance_ip=$(gcloud compute instances describe "$instance_name" \
            --zone="$zone" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
        
        if [[ -n "$instance_ip" ]]; then
            update_env_value "TARGET_SERVER_IP" "$instance_ip"
            gcp_log "Instance IP: $instance_ip"
        fi
        
        return 0
    else
        gcp_error "Failed to start instance"
        return 1
    fi
}

# Stop an instance
gcp_stop_instance() {
    local instance_name="${1:-$(get_env_value 'GCP_INSTANCE_NAME')}"
    local zone="${2:-$(get_env_value 'GCP_INSTANCE_ZONE')}"
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        gcp_error "Instance name or zone not specified"
        return 1
    fi
    
    gcp_log "Stopping instance: $instance_name"
    
    gcloud compute instances stop "$instance_name" --zone="$zone"
    
    if [[ $? -eq 0 ]]; then
        gcp_log "Instance stopped successfully"
        return 0
    else
        gcp_error "Failed to stop instance"
        return 1
    fi
}

# Delete an instance
gcp_delete_instance() {
    local instance_name="${1:-$(get_env_value 'GCP_INSTANCE_NAME')}"
    local zone="${2:-$(get_env_value 'GCP_INSTANCE_ZONE')}"
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        gcp_error "Instance name or zone not specified"
        return 1
    fi
    
    gcp_warn "This will permanently delete instance: $instance_name"
    read -r -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        gcp_log "Deleting instance: $instance_name"
        
        gcloud compute instances delete "$instance_name" --zone="$zone" --quiet
        
        if [[ $? -eq 0 ]]; then
            gcp_log "Instance deleted successfully"
            
            # Clear instance details from .env
            update_env_value "GCP_INSTANCE_NAME" ""
            update_env_value "GCP_INSTANCE_ZONE" ""
            update_env_value "GCP_USE_EXISTING_INSTANCE" "false"
            update_env_value "TARGET_SERVER_IP" ""
            
            return 0
        else
            gcp_error "Failed to delete instance"
            return 1
        fi
    else
        gcp_log "Instance deletion cancelled"
        return 1
    fi
}

# Get instance status
gcp_get_instance_status() {
    local instance_name="${1:-$(get_env_value 'GCP_INSTANCE_NAME')}"
    local zone="${2:-$(get_env_value 'GCP_INSTANCE_ZONE')}"
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        echo "unknown"
        return 1
    fi
    
    local status=$(gcloud compute instances describe "$instance_name" \
        --zone="$zone" \
        --format="value(status)" \
        2>/dev/null || echo "NOT_FOUND")
    
    echo "$status"
}

# List all Claude Code instances
gcp_list_claude_instances() {
    gcp_log "Claude Code instances:"
    
    gcloud compute instances list \
        --filter="labels.claude-code=true" \
        --format="table(name,zone.scope():label=ZONE,status:label=STATUS,machineType.scope():label=TYPE,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP,labels.strategy:label=STRATEGY)"
}

# Get instance cost estimate
gcp_estimate_costs() {
    local machine_type="${1:-$GCP_DEFAULT_MACHINE_TYPE}"
    local region="${2:-$(get_env_value 'GOOGLE_CLOUD_REGION' 'europe-north2')}"
    
    gcp_log "Cost estimate for $machine_type in $region:"
    echo "  • e2-small (1 vCPU, 2GB RAM): ~$12-15/month"
    echo "  • e2-medium (1 vCPU, 4GB RAM): ~$20-25/month"
    echo "  • e2-standard-2 (2 vCPU, 8GB RAM): ~$35-45/month"
    echo ""
    echo "Additional costs:"
    echo "  • Storage (20GB): ~$2/month"
    echo "  • Network egress: Variable"
    echo "  • Snapshots: ~$1-3/month"
    echo ""
    echo "Use 'gcloud compute machine-types describe' for exact pricing"
}

# SSH into instance
gcp_ssh_instance() {
    local instance_name="${1:-$(get_env_value 'GCP_INSTANCE_NAME')}"
    local zone="${2:-$(get_env_value 'GCP_INSTANCE_ZONE')}"
    local user="${3:-$(get_env_value 'CLAUDE_USER' 'claude-user')}"
    
    if [[ -z "$instance_name" || -z "$zone" ]]; then
        gcp_error "Instance name or zone not specified"
        return 1
    fi
    
    gcp_log "Connecting to $instance_name as $user..."
    
    # Check if instance is running
    local status=$(gcp_get_instance_status "$instance_name" "$zone")
    if [[ "$status" != "RUNNING" ]]; then
        gcp_warn "Instance is not running (status: $status)"
        read -r -p "Start instance? (y/N): " start_it
        if [[ "$start_it" =~ ^[Yy]$ ]]; then
            gcp_start_instance "$instance_name" "$zone"
            sleep 10
        else
            return 1
        fi
    fi
    
    gcloud compute ssh "$user@$instance_name" --zone="$zone"
}

# Create startup script for shared strategy
gcp_create_startup_scripts() {
    local script_dir="./scripts/implementation"
    
    # Create shared strategy startup script
    cat > "$script_dir/gcp-startup-shared.sh" << 'EOF'
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
EOF

    # Create dedicated strategy startup script
    cat > "$script_dir/gcp-startup-dedicated.sh" << 'EOF'
#!/bin/bash
# GCP startup script for dedicated Claude Code instance

set -euo pipefail

# Update system
apt update && apt upgrade -y

# Install base dependencies
apt install -y curl wget git build-essential software-properties-common

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Configure firewall (more restrictive for dedicated)
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from 10.0.0.0/8 to any port 8080
ufw allow from 10.0.0.0/8 to any port 8443
ufw --force enable

# Create claude-user if it doesn't exist
if ! id claude-user &>/dev/null; then
    useradd -r -m -s /bin/bash -c "Claude Code Service User" claude-user
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
echo "$(date): Claude Code dedicated instance setup completed" >> /var/log/gcp-startup.log
EOF

    chmod +x "$script_dir/gcp-startup-shared.sh"
    chmod +x "$script_dir/gcp-startup-dedicated.sh"
    
    gcp_log "Startup scripts created successfully"
}

# Enable required APIs
gcp_enable_apis() {
    local project=$(get_env_value "GOOGLE_CLOUD_PROJECT")
    
    if [[ -z "$project" ]]; then
        gcp_error "No project configured"
        return 1
    fi
    
    gcp_log "Enabling required APIs for project: $project"
    
    local apis=(
        "compute.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        gcp_log "Enabling $api..."
        gcloud services enable "$api" || gcp_warn "Failed to enable $api"
    done
    
    gcp_log "API enablement completed"
}

# Self-test when run directly (for development)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "gcloud_utils.sh - Google Cloud utilities for Claude Code"
    echo "This script should be sourced, not executed directly"
    exit 1
fi
