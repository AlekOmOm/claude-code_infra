#!/bin/bash
# scripts/phases/0_infrastructure_choice.sh
# Phase 0: Infrastructure Choice - Cloud vs Home Server

set -euo pipefail

ENV_UTILS_PATH="./scripts/implementation/env_utils.sh"
GCLOUD_UTILS_PATH="./scripts/implementation/gcloud_utils.sh"

if [ ! -f "$ENV_UTILS_PATH" ]; then
    echo "ERROR: Environment utilities not found at $ENV_UTILS_PATH" >&2
    exit 1
fi

source "$ENV_UTILS_PATH"
[[ -f "$GCLOUD_UTILS_PATH" ]] && source "$GCLOUD_UTILS_PATH"

echo "Phase 0: Infrastructure Choice"
echo "=============================="
echo ""

# Ensure .env file exists
ensure_env_file

# Check current infrastructure choice
current_choice=$(get_env_value "INFRASTRUCTURE_TYPE" "")

if [[ -n "$current_choice" && "$current_choice" != "CHOOSE_INFRASTRUCTURE_TYPE" ]]; then
    echo "Current infrastructure: $current_choice"
    echo ""
    read -r -p "Change infrastructure type? (y/N): " change_choice
    if [[ ! "$change_choice" =~ ^[Yy]$ ]]; then
        echo "Keeping current choice: $current_choice"
        exit 0
    fi
fi

echo "Choose your infrastructure deployment target:"
echo ""
echo "1. Home Server (existing/dedicated hardware)"
echo "   ✓ Full control and privacy"
echo "   ✓ No cloud costs"
echo "   ✗ Requires existing Ubuntu server"
echo ""
echo "2. Google Cloud Platform (managed instances)"  
echo "   ✓ No hardware management"
echo "   ✓ Automatic scaling and backups"
echo "   ✓ Development cost optimization"
echo "   ✗ Cloud costs (~$10-25/month with optimization)"
echo ""

while true; do
    read -r -p "Enter your choice (1 or 2): " choice
    case $choice in
        1)
            echo ""
            echo "Selected: Home Server deployment"
            update_env_value "INFRASTRUCTURE_TYPE" "home-server"
            
            # Prompt for server IP if not set
            current_ip=$(get_env_value "TARGET_SERVER_IP" "YOUR_SERVER_IP_HERE")
            if [[ "$current_ip" == "YOUR_SERVER_IP_HERE" ]]; then
                echo ""
                read -r -p "Enter your Ubuntu server IP address: " server_ip
                update_env_value "TARGET_SERVER_IP" "$server_ip"
            fi
            
            echo "✓ Home server configuration saved to .env"
            echo ""
            echo "Next steps:"
            echo "- Ensure your Ubuntu server is accessible via SSH"
            echo "- Run: ./scripts/phases/1_prerequisites_check.sh"
            break
            ;;
        2)
            echo ""
            echo "Selected: Google Cloud Platform deployment"
            update_env_value "INFRASTRUCTURE_TYPE" "gcloud"
            
            # Check for gcloud CLI
            if ! command -v gcloud &> /dev/null; then
                echo ""
                echo "⚠️  Google Cloud CLI not found!"
                echo "Install it from: https://cloud.google.com/sdk/docs/install"
                echo ""
                read -r -p "Continue anyway? (y/N): " continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    echo "Please install gcloud CLI and run this script again."
                    exit 1
                fi
            else
                # Setup GCP infrastructure
                setup_gcp_infrastructure
            fi
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

echo ""
echo "=========================================="
echo "Infrastructure choice configuration complete!"
echo "=========================================="

# Setup GCP infrastructure function
setup_gcp_infrastructure() {
    echo ""
    echo "Setting up Google Cloud Platform infrastructure..."
    
    # Check authentication
    setup_gcp_authentication
    
    # Choose project or create new
    setup_gcp_project
    
    # Instance management strategy
    setup_instance_strategy
    
    echo "✓ GCP configuration saved to .env"
    echo ""
    echo "Next steps:"
    echo "- Your GCP instance will be created during deployment"
    echo "- Run: ./scripts/phases/1_prerequisites_check.sh"
}

setup_gcp_authentication() {
    echo ""
    echo "Setting up Google Cloud authentication..."
    
    # Check current auth status
    if gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | head -1 | grep -q "@"; then
        current_account=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -1)
        echo "✓ Already authenticated as: $current_account"
        
        read -r -p "Use this account? (Y/n): " use_current
        if [[ "$use_current" =~ ^[Nn]$ ]]; then
            gcloud auth login
        fi
    else
        echo "Authentication required for Google Cloud..."
        echo ""
        echo "Choose authentication method:"
        echo "1. Interactive login (recommended for development)"
        echo "2. Service account key file (for automation/CI)"
        echo ""
        
        while true; do
            read -r -p "Enter your choice (1 or 2): " auth_choice
            case $auth_choice in
                1)
                    echo "Opening browser for authentication..."
                    gcloud auth login
                    gcloud auth application-default login
                    break
                    ;;
                2)
                    echo ""
                    read -r -p "Enter path to service account key file: " key_file
                    if [[ -f "$key_file" ]]; then
                        gcloud auth activate-service-account --key-file="$key_file"
                        update_env_value "GOOGLE_APPLICATION_CREDENTIALS" "$key_file"
                        echo "✓ Service account authentication configured"
                    else
                        echo "Key file not found: $key_file"
                        continue
                    fi
                    break
                    ;;
                *)
                    echo "Invalid choice. Please enter 1 or 2."
                    ;;
            esac
        done
    fi
    
    update_env_value "GCP_AUTH_METHOD" "configured"
}

setup_gcp_project() {
    echo ""
    echo "Setting up Google Cloud project..."
    
    # Get current project
    current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    
    if [[ -n "$current_project" ]]; then
        echo "Current project: $current_project"
        read -r -p "Use this project? (Y/n): " use_current
        if [[ "$use_current" =~ ^[Nn]$ ]]; then
            select_or_create_project
        else
            update_env_value "GOOGLE_CLOUD_PROJECT" "$current_project"
        fi
    else
        select_or_create_project
    fi
    
    # Set region
    echo ""
    echo "Select region for Claude Code deployment:"
    echo "1. europe-north2 (Stockholm) - Cost optimized"
    echo "2. europe-west1 (Belgium) - Lower latency"
    echo "3. us-central1 (Iowa) - General purpose"
    echo ""
    
    while true; do
        read -r -p "Enter choice (1-3): " region_choice
        case $region_choice in
            1)
                update_env_value "GOOGLE_CLOUD_REGION" "europe-north2"
                update_env_value "GOOGLE_CLOUD_ZONE" "europe-north2-a"
                break
                ;;
            2)
                update_env_value "GOOGLE_CLOUD_REGION" "europe-west1"
                update_env_value "GOOGLE_CLOUD_ZONE" "europe-west1-b"
                break
                ;;
            3)
                update_env_value "GOOGLE_CLOUD_REGION" "us-central1"
                update_env_value "GOOGLE_CLOUD_ZONE" "us-central1-a"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

select_or_create_project() {
    echo ""
    echo "Available projects:"
    projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null || echo "")
    
    if [[ -n "$projects" ]]; then
        echo "$projects" | nl
        echo ""
        read -r -p "Enter project number, or 'new' to create: " selection
        
        if [[ "$selection" == "new" ]]; then
            create_new_project
        elif [[ "$selection" =~ ^[0-9]+$ ]]; then
            selected_project=$(echo "$projects" | sed -n "${selection}p")
            if [[ -n "$selected_project" ]]; then
                gcloud config set project "$selected_project"
                update_env_value "GOOGLE_CLOUD_PROJECT" "$selected_project"
                echo "✓ Using project: $selected_project"
            else
                echo "Invalid selection"
                select_or_create_project
            fi
        else
            echo "Invalid input"
            select_or_create_project
        fi
    else
        echo "No projects found. Creating new project..."
        create_new_project
    fi
}

create_new_project() {
    echo ""
    read -r -p "Enter new project ID (lowercase, numbers, hyphens): " project_id
    read -r -p "Enter project name: " project_name
    
    if gcloud projects create "$project_id" --name="$project_name"; then
        gcloud config set project "$project_id"
        update_env_value "GOOGLE_CLOUD_PROJECT" "$project_id"
        echo "✓ Created and configured project: $project_id"
        
        # Enable required APIs
        echo "Enabling required APIs..."
        gcloud services enable compute.googleapis.com
        gcloud services enable cloudresourcemanager.googleapis.com
    else
        echo "Failed to create project. Try a different project ID."
        create_new_project
    fi
}

setup_instance_strategy() {
    echo ""
    echo "Configure Claude Code instance strategy:"
    echo ""
    echo "1. Single shared instance (cost-effective)"
    echo "   → Multiple repositories as different users on one server"
    echo "   → ~$15-25/month total"
    echo ""
    echo "2. Multiple dedicated instances (maximum isolation)"  
    echo "   → Each major project gets its own server"
    echo "   → ~$15-25/month per project"
    echo ""
    
    while true; do
        read -r -p "Enter your choice (1 or 2): " strategy_choice
        case $strategy_choice in
            1)
                update_env_value "GCP_INSTANCE_STRATEGY" "shared"
                update_env_value "GCP_MACHINE_TYPE" "e2-medium"
                echo "✓ Configured for shared instance with multi-user support"
                break
                ;;
            2)
                update_env_value "GCP_INSTANCE_STRATEGY" "dedicated"
                update_env_value "GCP_MACHINE_TYPE" "e2-small"
                echo "✓ Configured for dedicated instances per project"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    # Check for existing instances
    check_existing_instances
}

check_existing_instances() {
    echo ""
    echo "Checking for existing Claude Code instances..."
    
    project=$(get_env_value "GOOGLE_CLOUD_PROJECT")
    if [[ -z "$project" ]]; then
        echo "No project configured yet"
        return
    fi
    
    existing_instances=$(gcloud compute instances list \
        --filter="labels.claude-code=true" \
        --format="value(name,zone,status)" \
        2>/dev/null || echo "")
    
    if [[ -n "$existing_instances" ]]; then
        echo "Found existing Claude Code instances:"
        echo "$existing_instances" | while IFS=$'\t' read -r name zone status; do
            echo "  $name (zone: $zone, status: $status)"
        done
        echo ""
        
        read -r -p "Use existing instance(s)? (Y/n): " use_existing
        if [[ ! "$use_existing" =~ ^[Nn]$ ]]; then
            # Select instance to use
            instance_names=$(echo "$existing_instances" | cut -f1)
            if [[ $(echo "$instance_names" | wc -l) -eq 1 ]]; then
                selected_instance="$instance_names"
                selected_zone=$(echo "$existing_instances" | cut -f2)
            else
                echo "Multiple instances found. Select one:"
                echo "$instance_names" | nl
                read -r -p "Enter number: " selection
                selected_instance=$(echo "$instance_names" | sed -n "${selection}p")
                selected_zone=$(echo "$existing_instances" | sed -n "${selection}p" | cut -f2)
            fi
            
            if [[ -n "$selected_instance" ]]; then
                update_env_value "GCP_INSTANCE_NAME" "$selected_instance"
                update_env_value "GCP_INSTANCE_ZONE" "$selected_zone"
                update_env_value "GCP_USE_EXISTING_INSTANCE" "true"
                
                # Get instance IP
                instance_ip=$(gcloud compute instances describe "$selected_instance" \
                    --zone="$selected_zone" \
                    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
                    2>/dev/null || echo "")
                
                if [[ -n "$instance_ip" ]]; then
                    update_env_value "TARGET_SERVER_IP" "$instance_ip"
                    echo "✓ Using existing instance: $selected_instance ($instance_ip)"
                fi
            fi
        fi
    else
        echo "No existing Claude Code instances found."
        echo "A new instance will be created during deployment."
        update_env_value "GCP_USE_EXISTING_INSTANCE" "false"
    fi
}
