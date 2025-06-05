#!/bin/bash
set -euo pipefail

# Claude Code Infrastructure Deployment Script
# Usage: ./deploy_claude_infrastructure.sh [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default configuration
CLAUDE_USER="claude-user"
SERVER_IP="192.168.1.100"
GITHUB_TOKEN=""
SSH_PUBLIC_KEY=""
DEPLOY_MODE="production"
ENABLE_MCP_SERVER=true

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

usage() {
    cat <<EOF
Claude Code Infrastructure Deployment

Usage: $0 [OPTIONS]

Options:
    -u, --user USER         Claude service user (default: claude-user)
    -i, --ip IP            Server IP address (default: 192.168.1.100)
    -t, --token TOKEN      GitHub token for MCP integration
    -k, --ssh-key PATH     Path to SSH public key
    -m, --mode MODE        Deployment mode: dev|staging|production (default: production)
    --no-mcp              Disable MCP server deployment
    -h, --help            Show this help message

Examples:
    $0 --token ghp_xxx --ssh-key ~/.ssh/id_rsa.pub
    $0 --user claude-dev --mode staging --no-mcp
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            CLAUDE_USER="$2"
            shift 2
            ;;
        -i|--ip)
            SERVER_IP="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_PUBLIC_KEY="$(cat "$2")"
            shift 2
            ;;
        -m|--mode)
            DEPLOY_MODE="$2"
            shift 2
            ;;
        --no-mcp)
            ENABLE_MCP_SERVER=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$GITHUB_TOKEN" ]]; then
    print_error "GitHub token is required. Use --token option."
    exit 1
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
    print_error "SSH public key is required. Use --ssh-key option."
    exit 1
fi

print_status "Starting Claude Code infrastructure deployment..."
print_status "Configuration:"
print_status "  User: $CLAUDE_USER"
print_status "  Server IP: $SERVER_IP"
print_status "  Deploy Mode: $DEPLOY_MODE"
print_status "  MCP Server: $ENABLE_MCP_SERVER"

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    exit 1
fi

# Check required tools
required_tools=("terraform" "node" "npm" "git" "gh")
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

# Check Terraform version
terraform_version=$(terraform --version | head -n1 | cut -d' ' -f2 | sed 's/v//')
required_terraform="1.5.0"
if ! printf '%s\n%s\n' "$required_terraform" "$terraform_version" | sort -V -C; then
    print_error "Terraform version $required_terraform or higher is required"
    exit 1
fi

# Phase 1: System preparation
print_status "Phase 1: System preparation"

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required system packages
print_status "Installing system dependencies..."
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    unzip

# Phase 2: Infrastructure deployment with Terraform
print_status "Phase 2: Infrastructure deployment"

cd "$PROJECT_ROOT/terraform"

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Create terraform.tfvars
print_status "Creating Terraform configuration..."
cat > terraform.tfvars <<EOF
claude_user    = "$CLAUDE_USER"
server_ip      = "$SERVER_IP"
github_token   = "$GITHUB_TOKEN"
ssh_public_key = "$SSH_PUBLIC_KEY"
EOF

# Plan deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply deployment
print_status "Applying Terraform configuration..."
terraform apply tfplan

# Phase 3: Service configuration
print_status "Phase 3: Service configuration"

# Configure firewall
print_status "Configuring firewall..."
"$SCRIPT_DIR/configure_firewall.sh"

# Start services
print_status "Starting Claude Code services..."
sudo systemctl start claude-services.slice
sudo systemctl start claude-code.service

if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    sudo systemctl start claude-mcp-server.service
fi

# Phase 4: Verification
print_status "Phase 4: Deployment verification"

# Check service status
print_status "Verifying service status..."
systemctl status claude-code.service --no-pager
if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    systemctl status claude-mcp-server.service --no-pager
fi

# Check firewall status
print_status "Verifying firewall configuration..."
sudo ufw status

# Test Claude Code installation
print_status "Testing Claude Code installation..."
sudo -u "$CLAUDE_USER" bash -c '
    source ~/.bashrc
    claude --version
'

# Phase 5: Post-deployment setup
print_status "Phase 5: Post-deployment setup"

# Create sample workspace
print_status "Creating sample workspace..."
sudo -u "$CLAUDE_USER" mkdir -p "/home/$CLAUDE_USER/workspaces/sample-project"

# Generate documentation
print_status "Generating deployment documentation..."
cat > "$PROJECT_ROOT/DEPLOYMENT_SUMMARY.md" <<EOF
# Claude Code Deployment Summary

## Configuration
- **User**: $CLAUDE_USER
- **Server IP**: $SERVER_IP
- **Deploy Mode**: $DEPLOY_MODE
- **MCP Server**: $ENABLE_MCP_SERVER

## Services
- claude-code.service: $(systemctl is-active claude-code.service)
$(if [[ "$ENABLE_MCP_SERVER" == true ]]; then echo "- claude-mcp-server.service: $(systemctl is-active claude-mcp-server.service)"; fi)

## Access Information
- SSH: ssh $CLAUDE_USER@$SERVER_IP
- Claude Workspace: /home/$CLAUDE_USER/workspaces/
$(if [[ "$ENABLE_MCP_SERVER" == true ]]; then echo "- MCP Server: http://$SERVER_IP:9090"; fi)

## Management Commands
- Start services: sudo systemctl start claude-services.slice
- Stop services: sudo systemctl stop claude-services.slice
- View logs: journalctl -u claude-code.service -f
- Check status: systemctl status claude-code.service

## Security
- Firewall: $(sudo ufw status | head -n1)
- Service isolation: Active (systemd sandboxing)
- Audit logging: $(systemctl is-active auditd)

Deployment completed: $(date)
EOF

print_status "Deployment completed successfully!"
print_status "Summary written to: $PROJECT_ROOT/DEPLOYMENT_SUMMARY.md"
print_status ""
print_status "Next steps:"
print_status "1. SSH to server: ssh $CLAUDE_USER@$SERVER_IP"
print_status "2. Navigate to workspace: cd ~/workspaces/"
print_status "3. Initialize Claude Code: claude init"
print_status "4. Start coding with AI assistance!"

if [[ "$ENABLE_MCP_SERVER" == true ]]; then
    print_status "5. MCP Server available at: http://$SERVER_IP:9090"
fi