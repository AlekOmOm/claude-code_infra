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

# Check if all required environment variables are set
print_status "Checking configuration status..."

REQUIRED_VARS=(
    "TARGET_SERVER_IP=YOUR_SERVER_IP_HERE"
    "SSH_KEY_PATH=YOUR_SSH_KEY_PATH_HERE"
    "GITHUB_PAT=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE"
    "ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY_HERE"
    "CLAUDE_USER=claude-user"
    "DEPLOY_MODE=production"
    "ENABLE_MCP_SERVER=true"
)

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
            
            # Get the project directory
            PROJECT_DIR=$(get_env_value "CLAUDE_PROJECT_DIR" "/home/$CLAUDE_USER/workspaces/sample-project")
            
            # SSH into the server and run claude
            print_status "Launching Claude in $PROJECT_DIR..."
            echo "Use 'exit' to return to this menu."
            echo ""
            
            ssh -t "${CLAUDE_USER}@${TARGET_SERVER_IP}" "cd $PROJECT_DIR && claude"
        else
            print_status "You can connect manually using:"
            echo "  ssh ${CLAUDE_USER}@${TARGET_SERVER_IP}"
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
        # Run deployment phase
        if ! "$PHASES_DIR/4_execute_deployment_template.sh"; then
            print_error "Deployment failed. Please check the output above."
            exit 1
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
        # Run deployment phase
        print_status "Starting deployment..."
        echo ""
        
        if ! "$PHASES_DIR/4_execute_deployment_template.sh"; then
            print_error "Deployment failed. Please check the output above."
            exit 1
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