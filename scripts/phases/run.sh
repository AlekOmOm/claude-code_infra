#!/bin/bash
# Main orchestration script for Claude Code Infrastructure deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PHASES_DIR="$SCRIPT_DIR"
IMPL_DIR="$(dirname "$SCRIPT_DIR")/implementation"

# Source utilities
source "$IMPL_DIR/env_utils.sh"
source "$IMPL_DIR/os_utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

# Header
echo ""
echo "======================================"
echo "Claude Code Infrastructure Orchestrator"
echo "======================================"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Ensure .env file exists
ensure_env_file

# Check infrastructure type first
infrastructure_type=$(get_env_value "INFRASTRUCTURE_TYPE" "")

if [[ -z "$infrastructure_type" || "$infrastructure_type" == "CHOOSE_INFRASTRUCTURE_TYPE" ]]; then
    print_status "Infrastructure type not selected. Running infrastructure choice..."
    echo ""
    
    # Phase 0: Infrastructure choice
    if ! "$PHASES_DIR/0_infrastructure_choice.sh"; then
        print_error "Infrastructure choice failed. Please try again."
        exit 1
    fi
    echo ""
    
    # Reload configuration after infrastructure choice
    source .env
    infrastructure_type=$(get_env_value "INFRASTRUCTURE_TYPE" "")
fi

print_status "Infrastructure type: $infrastructure_type"

# Check if all required environment variables are set
print_status "Checking configuration status..."

# Base required variables for all deployment types
BASE_REQUIRED_VARS=(
    "SSH_PUBLIC_KEY_PATH=/path/to/your/ssh_public_key.pub"
    "GITHUB_PAT=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE"
    "ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY_HERE"
    "CLAUDE_USER_NAME=claude-user"
    "DEPLOYMENT_MODE=production"
    "ENABLE_MCP_SERVER=true"
)

# Add infrastructure-specific required variables
REQUIRED_VARS=("${BASE_REQUIRED_VARS[@]}")

if [[ "$infrastructure_type" == "home-server" ]]; then
    REQUIRED_VARS+=("TARGET_SERVER_IP=YOUR_SERVER_IP_HERE")
elif [[ "$infrastructure_type" == "gcloud" ]]; then
    REQUIRED_VARS+=(
        "GOOGLE_CLOUD_PROJECT="
        "GOOGLE_CLOUD_REGION="
        "GOOGLE_CLOUD_ZONE="
        "GCP_INSTANCE_STRATEGY="
        "GCP_MACHINE_TYPE="
    )
fi

CONFIG_COMPLETE=true
if ! check_required_env_vars ".env" "${REQUIRED_VARS[@]}"; then
    CONFIG_COMPLETE=false
fi

# If configuration is incomplete, run phases 1-3
if [ "$CONFIG_COMPLETE" = false ]; then
    print_warning "Configuration incomplete. Running setup phases..."
    echo ""
    
    # Phase 1: Prerequisites check
    print_status "Phase 1: Checking prerequisites..."
    if ! "$PHASES_DIR/1_prerequisites_check.sh"; then
        print_error "Prerequisites check failed. Please resolve issues and run again."
        exit 1
    fi
    echo ""
    
    # Phase 2: Information gathering
    print_status "Phase 2: Gathering deployment information..."
    if ! "$PHASES_DIR/2_information_gathering_input.sh"; then
        print_error "Information gathering failed. Please try again."
        exit 1
    fi
    echo ""
    
    # Phase 3: Deployment configuration
    print_status "Phase 3: Configuring deployment options..."
    if ! "$PHASES_DIR/3_deployment_configuration_input.sh"; then
        print_error "Deployment configuration failed. Please try again."
        exit 1
    fi
    echo ""
else
    print_status "Configuration complete. Using existing .env file."
    echo ""
fi

# Load configuration
source .env

# Check if already deployed
print_status "Checking deployment status..."

# Create deployment check utility if it doesn't exist
if [ ! -f "$IMPL_DIR/utils/deploy_check_utils.sh" ]; then
    mkdir -p "$IMPL_DIR/utils"
    # We'll create this file next
fi

# Source deployment check utilities
source "$IMPL_DIR/utils/deploy_check_utils.sh"

DEPLOYMENT_STATUS=$(check_deployment_status)

if [ "$DEPLOYMENT_STATUS" = "deployed" ]; then
    print_status "Claude Code is already deployed on $TARGET_SERVER_IP"
    echo ""
    
    # Check remote environment health
    print_status "Checking remote environment health..."
    
    # Create remote environment check utility if it doesn't exist
    if [ ! -f "$IMPL_DIR/utils/remote_environment_check.sh" ]; then
        # We'll create this file next
    fi
    
    # Source and run environment check
    source "$IMPL_DIR/utils/remote_environment_check.sh"
    
    ENV_STATUS=$(check_remote_environment)
    
    if [ "$ENV_STATUS" = "healthy" ]; then
        print_status "Remote environment is healthy!"
        echo ""
        
        # Ask if user wants to connect
        print_prompt "Would you like to connect to Claude Code now? (y/n): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_status "Connecting to Claude Code..."
            echo ""
            
            # Handle different infrastructure types
            if [[ "$infrastructure_type" == "gcloud" ]]; then
                # Use GCP SSH connection
                local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
                local zone=$(get_env_value "GCP_INSTANCE_ZONE")
                local claude_user=$(get_env_value "CLAUDE_USER_NAME" "claude-user")
                
                if [[ -n "$instance_name" && -n "$zone" ]]; then
                    print_status "Connecting via Google Cloud..."
                    source "$IMPL_DIR/gcloud_utils.sh"
                    gcp_ssh_instance "$instance_name" "$zone" "$claude_user"
                else
                    print_error "GCP instance details not found. Please check your configuration."
                fi
            else
                # Home server SSH connection
                local project_dir=$(get_env_value "CLAUDE_PROJECT_DIR" "/home/$CLAUDE_USER_NAME/workspaces/sample-project")
                print_status "Launching Claude in $project_dir..."
                echo "Use 'exit' to return to this menu."
                echo ""
                ssh -t "${CLAUDE_USER_NAME}@${TARGET_SERVER_IP}" "cd $project_dir && claude"
            fi
        else
            print_status "You can connect manually using:"
            if [[ "$infrastructure_type" == "gcloud" ]]; then
                local instance_name=$(get_env_value "GCP_INSTANCE_NAME")
                local zone=$(get_env_value "GCP_INSTANCE_ZONE")
                echo "  gcloud compute ssh ${CLAUDE_USER_NAME}@${instance_name} --zone=${zone}"
            else
                echo "  ssh ${CLAUDE_USER_NAME}@${TARGET_SERVER_IP}"
            fi
            echo "  cd ~/workspaces/sample-project"
            echo "  claude"
        fi
    else
        print_warning "Remote environment needs attention. Running verification..."
        echo ""
        
        # Run phase 5 verification
        if ! "$PHASES_DIR/5_post_deployment_verification.sh"; then
            print_error "Verification found issues. Please check the output above."
        fi
    fi
    
elif [ "$DEPLOYMENT_STATUS" = "partial" ]; then
    print_warning "Partial deployment detected. Some components may be missing."
    echo ""
    
    print_prompt "Would you like to complete the deployment? (y/n): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Run deployment phase based on infrastructure type
        if [[ "$infrastructure_type" == "gcloud" ]]; then
            print_status "Completing GCP deployment..."
            source "$IMPL_DIR/gcp_deploy.sh"
            gcp_deploy_claude_infrastructure
        else
            if ! "$PHASES_DIR/4_execute_deployment_template.sh"; then
                print_error "Deployment failed. Please check the output above."
                exit 1
            fi
        fi
        
        # Run verification
        if ! "$PHASES_DIR/5_post_deployment_verification.sh"; then
            print_warning "Post-deployment verification found issues."
        fi
    fi
    
else
    # Not deployed
    print_status "Claude Code is not yet deployed."
    echo ""
    
    print_prompt "Would you like to deploy now? (y/n): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Run deployment phase based on infrastructure type
        print_status "Starting deployment..."
        echo ""
        
        if [[ "$infrastructure_type" == "gcloud" ]]; then
            print_status "Deploying to Google Cloud Platform..."
            source "$IMPL_DIR/gcp_deploy.sh"
            gcp_deploy_claude_infrastructure
        else
            print_status "Deploying to home server..."
            if ! "$PHASES_DIR/4_execute_deployment_template.sh"; then
                print_error "Deployment failed. Please check the output above."
                exit 1
            fi
        fi
        echo ""
        
        # Run verification
        print_status "Running post-deployment verification..."
        if ! "$PHASES_DIR/5_post_deployment_verification.sh"; then
            print_warning "Post-deployment verification found issues."
        fi
    else
        print_status "Deployment cancelled. You can run this script again when ready."
    fi
fi

echo ""
echo "======================================"
echo "Orchestration complete!"
echo "======================================"
echo ""
