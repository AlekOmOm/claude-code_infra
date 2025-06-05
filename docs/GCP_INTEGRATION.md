# Google Cloud Platform Integration for Claude Code Infrastructure

## Overview

This document describes the Google Cloud Platform (GCP) integration added to the Claude Code Infrastructure project. The integration provides an alternative to home server deployment, offering managed cloud instances with automatic provisioning, backup scheduling, and cost optimization.

## Key Features

### 🎯 Infrastructure Choice
- **Phase 0**: New infrastructure selection workflow
- Choose between home server or Google Cloud Platform deployment
- Automatic configuration and prerequisite checking

### ☁️ Google Cloud Integration
- **Automated Instance Creation**: E2-medium instances with optimized configurations
- **VPC Network Setup**: Dedicated network with proper firewall rules
- **Backup Scheduling**: Automatic daily snapshots with 14-day retention
- **Cost Optimization**: Start/stop instances to minimize costs (~$15-25/month)

### 🚀 Deployment Strategies
- **Shared Instance**: Multiple repositories on one server (cost-effective)
- **Dedicated Instance**: Each project gets its own isolated server
- **Existing Instance**: Reuse existing Claude Code instances

## Usage

### Quick Start

```bash
# Launch the orchestrator with GCP support
./run.sh

# Select Google Cloud Platform when prompted
# Follow the interactive setup for authentication and project configuration
```

### Manual GCP Operations

```bash
# Direct GCP deployment script usage
./scripts/implementation/gcp_deploy.sh deploy

# Instance management
./scripts/implementation/gcp_deploy.sh start     # Start instance
./scripts/implementation/gcp_deploy.sh stop     # Stop instance (saves costs)
./scripts/implementation/gcp_deploy.sh connect  # SSH to instance
./scripts/implementation/gcp_deploy.sh status   # Check instance status
./scripts/implementation/gcp_deploy.sh list     # List all Claude instances
./scripts/implementation/gcp_deploy.sh costs    # Show cost estimates
```

### Prerequisites for GCP Deployment

1. **Google Cloud CLI**: Automatically checked and installed if needed
2. **GCP Project**: Created or selected during setup
3. **Authentication**: Interactive login or service account key
4. **APIs**: Automatically enabled (Compute, Cloud Resource Manager)

## Architecture

### Instance Configuration

```yaml
Machine Type: e2-medium (1 vCPU, 4GB RAM)
Disk: 20GB standard persistent disk
Network: Custom VPC with restricted firewall rules
OS: Debian 12 (latest)
Security: SSH key-based access, firewall restrictions
```

### Network Security

```yaml
Firewall Rules:
  - SSH: Port 22 (rate limited)
  - Claude Code: Ports 8080, 8443 (local network only)
  - MCP Server: Port 9090 (internal network only)
  - Management: Limited to private IP ranges
```

### Backup Strategy

```yaml
Snapshots:
  - Schedule: Daily at 2:00 AM
  - Retention: 14 days
  - Storage: EU region
  - Automation: Fully automated via resource policies
```

## File Structure

### New Scripts Added

```
scripts/
├── phases/
│   └── 0_infrastructure_choice.sh          # Infrastructure selection
├── implementation/
│   ├── gcloud_utils.sh                     # GCP utility functions
│   ├── gcp_deploy.sh                       # Main GCP deployment
│   ├── gcp-startup-shared.sh               # Shared instance startup
│   └── gcp-startup-dedicated.sh            # Dedicated instance startup
```

### Configuration Changes

```
.env.template                                # Added GCP variables
scripts/phases/1_prerequisites_check.sh     # Added gcloud CLI check
scripts/phases/run.sh                       # Added GCP orchestration
scripts/implementation/1_install-prerequisites.sh  # Added gcloud installation
```

## Configuration Variables

### GCP-Specific Environment Variables

```bash
# Infrastructure Choice
INFRASTRUCTURE_TYPE="gcloud"              # "home-server" or "gcloud"

# GCP Project and Authentication
GOOGLE_CLOUD_PROJECT="your-project-id"    # GCP project ID
GOOGLE_CLOUD_REGION="europe-north2"       # Deployment region
GOOGLE_CLOUD_ZONE="europe-north2-a"       # Deployment zone
GCP_AUTH_METHOD="configured"               # Authentication status
GOOGLE_APPLICATION_CREDENTIALS="/path"     # Service account key (optional)

# Instance Configuration
GCP_INSTANCE_STRATEGY="shared"             # "shared" or "dedicated"
GCP_MACHINE_TYPE="e2-medium"               # GCP machine type
GCP_INSTANCE_NAME="claude-code-20250605"   # Instance name (auto-generated)
GCP_INSTANCE_ZONE="europe-north2-a"        # Instance zone
GCP_USE_EXISTING_INSTANCE="false"          # Use existing instance
```

## Cost Management

### Estimated Monthly Costs

```
Shared Strategy (e2-medium):
  - Compute: ~$20-25/month (continuous)
  - Storage: ~$2/month (20GB)
  - Snapshots: ~$1-3/month
  - Total: ~$25-30/month

Dedicated Strategy (e2-small):
  - Compute: ~$12-15/month per instance
  - Storage: ~$2/month per instance
  - Snapshots: ~$1/month per instance
  - Total: ~$15-18/month per project

Cost Optimization:
  - Stop instances when not in use
  - Use preemptible instances (advanced)
  - Schedule automatic start/stop
```

### Cost Optimization Commands

```bash
# Stop instance to save costs (preserves data)
./scripts/implementation/gcp_deploy.sh stop

# Start instance when needed
./scripts/implementation/gcp_deploy.sh start

# Check current costs
gcloud billing budgets list
```

## Security Features

### Instance Security
- **Dedicated VPC**: Isolated network environment
- **Firewall Rules**: Restrictive access controls
- **SSH Keys**: Key-based authentication only
- **Service Account**: Minimal required permissions
- **OS Security**: Regular automated updates

### Network Security
- **Private Subnets**: 10.0.0.0/24 internal network
- **NAT Gateway**: Outbound internet access only
- **Port Restrictions**: Limited to required services
- **Source IP Filtering**: Local network access only

## Troubleshooting

### Common Issues

**Authentication Problems**
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Check current authentication
gcloud auth list
```

**Instance Creation Failures**
```bash
# Check quotas
gcloud compute project-info describe --project=YOUR_PROJECT

# Verify APIs are enabled
gcloud services list --enabled
```

**Connection Issues**
```bash
# Check firewall rules
gcloud compute firewall-rules list

# Verify instance status
gcloud compute instances list
```

**Cost Concerns**
```bash
# Check current usage
gcloud compute instances list --format="table(name,status,machineType.basename(),zone.basename())"

# Stop all Claude instances
gcloud compute instances stop $(gcloud compute instances list --filter="labels.claude-code=true" --format="value(name)") --zone=YOUR_ZONE
```

### Debugging Commands

```bash
# Instance logs
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="journalctl -u claude-code.service -f"

# Startup script logs
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="sudo cat /var/log/gcp-startup.log"

# Resource usage
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="htop"
```

## Integration with Existing Workflow

### Backward Compatibility
- Home server deployment remains unchanged
- Existing configuration files are preserved
- All original features continue to work

### Workflow Changes
- **Phase 0**: New infrastructure choice step
- **Prerequisites**: Automatic gcloud CLI installation
- **Orchestrator**: Infrastructure-aware deployment paths
- **Connection**: Platform-specific SSH handling

### Migration Path
```bash
# From home server to GCP
1. Run: ./scripts/phases/0_infrastructure_choice.sh
2. Select: Google Cloud Platform
3. Follow setup prompts
4. Deploy: ./run.sh

# From GCP to home server
1. Edit .env: INFRASTRUCTURE_TYPE="home-server"
2. Add: TARGET_SERVER_IP="your.server.ip"
3. Deploy: ./run.sh
```

## Advanced Configuration

### Custom Machine Types
```bash
# Edit .env file
GCP_MACHINE_TYPE="e2-standard-2"  # 2 vCPU, 8GB RAM
GCP_MACHINE_TYPE="e2-small"       # 1 vCPU, 2GB RAM (cost-effective)
```

### Multi-Region Deployment
```bash
# Europe (Stockholm) - Cost optimized
GOOGLE_CLOUD_REGION="europe-north2"
GOOGLE_CLOUD_ZONE="europe-north2-a"

# Europe (Belgium) - Lower latency
GOOGLE_CLOUD_REGION="europe-west1"
GOOGLE_CLOUD_ZONE="europe-west1-b"

# US (Iowa) - General purpose
GOOGLE_CLOUD_REGION="us-central1"
GOOGLE_CLOUD_ZONE="us-central1-a"
```

### Service Account Setup (Advanced)
```bash
# Create service account
gcloud iam service-accounts create claude-code-sa \
    --description="Claude Code service account" \
    --display-name="Claude Code"

# Grant necessary permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:claude-code-sa@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.instanceAdmin.v1"

# Create and download key
gcloud iam service-accounts keys create key.json \
    --iam-account=claude-code-sa@PROJECT_ID.iam.gserviceaccount.com

# Set in .env
GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
```

## Performance Optimization

### Instance Sizing Guidelines
```bash
# Development/Personal Use
GCP_MACHINE_TYPE="e2-small"       # 1 vCPU, 2GB RAM (~$12/month)

# Standard Development
GCP_MACHINE_TYPE="e2-medium"      # 1 vCPU, 4GB RAM (~$20/month)

# Heavy Development/Multiple Projects
GCP_MACHINE_TYPE="e2-standard-2"  # 2 vCPU, 8GB RAM (~$40/month)

# Compute-Intensive Workloads
GCP_MACHINE_TYPE="c2-standard-4"  # 4 vCPU, 16GB RAM (~$120/month)
```

### Disk Optimization
```bash
# Standard persistent disk (default)
--boot-disk-type="pd-standard"

# SSD persistent disk (better performance)
--boot-disk-type="pd-ssd"

# Balanced persistent disk (cost/performance)
--boot-disk-type="pd-balanced"
```

## Monitoring and Alerts

### Basic Monitoring
```bash
# Instance metrics
gcloud compute instances list --format="table(name,status,machineType.basename(),zone.basename())"

# Resource usage
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="free -h && df -h"

# Service status
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="systemctl status claude-code.service"
```

### Cost Alerts (Optional)
```bash
# Create budget alert
gcloud billing budgets create \
    --billing-account=BILLING_ACCOUNT_ID \
    --display-name="Claude Code Budget" \
    --budget-amount=50USD \
    --threshold-rule=percent=0.9,basis=CURRENT_SPEND
```

## Best Practices

### Security
1. **Regular Updates**: Keep instances updated with latest security patches
2. **SSH Keys**: Use strong SSH keys and rotate regularly
3. **Firewall Rules**: Regularly review and update firewall configurations
4. **Access Logging**: Monitor SSH access and service logs

### Cost Management
1. **Stop When Idle**: Always stop instances when not in use
2. **Right-Size**: Choose appropriate machine types for workload
3. **Monitor Usage**: Set up billing alerts and monitor costs
4. **Cleanup**: Remove unused instances and resources

### Performance
1. **Regional Proximity**: Choose regions close to your location
2. **Instance Types**: Use compute-optimized instances for CPU-intensive tasks
3. **Disk Types**: Use SSD for better I/O performance
4. **Resource Monitoring**: Monitor CPU, memory, and disk usage

## Examples

### Complete GCP Deployment Example
```bash
# 1. Initial setup
git clone https://github.com/your-org/claude-code_infra.git
cd claude-code_infra

# 2. Launch orchestrator
./run.sh

# 3. Select infrastructure type
# Choose: 2. Google Cloud Platform

# 4. Authentication
# Browser opens for Google Cloud authentication

# 5. Project setup
# Select existing project or create new one
# Choose region: europe-north2 (Stockholm)

# 6. Instance strategy
# Choose: 1. Single shared instance

# 7. Deployment proceeds automatically
# Instance created, configured, and Claude Code installed

# 8. Connection
# SSH automatically configured and ready for use
```

### Daily Usage Example
```bash
# Morning: Start your instance
./scripts/implementation/gcp_deploy.sh start

# Connect and work
./scripts/implementation/gcp_deploy.sh connect

# Evening: Stop instance to save costs
./scripts/implementation/gcp_deploy.sh stop
```

### Multi-Project Setup Example
```bash
# Project 1: Web Development
GCP_INSTANCE_STRATEGY="dedicated"
GCP_MACHINE_TYPE="e2-medium"
./run.sh

# Project 2: Data Science
GCP_INSTANCE_STRATEGY="dedicated"
GCP_MACHINE_TYPE="e2-standard-2"
./run.sh

# Project 3: Shared Development
GCP_INSTANCE_STRATEGY="shared"
GCP_MACHINE_TYPE="e2-standard-4"
./run.sh
```

This integration provides a robust, cost-effective, and secure cloud alternative to home server deployment while maintaining the full functionality and user experience of the Claude Code infrastructure.
