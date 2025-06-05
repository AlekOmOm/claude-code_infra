# Terraform Infrastructure for Claude Code

This directory contains the Terraform configuration for provisioning Claude Code infrastructure. 

## Important Note

The main deployment flow uses shell scripts in the `scripts/src/` directory, not Terraform directly. The Terraform modules documented in the main README are for reference and future implementation.

Currently, the deployment is handled by:
- `scripts/src/deploy_claude_infrastructure.sh` - Main deployment script
- `scripts/src/configure_firewall.sh` - Firewall configuration
- Various utility scripts in `scripts/implementation/`

## Structure

If you want to use Terraform instead of the shell scripts, you would need to:

1. Create the module directories:
   ```
   tf/
   ├── main.tf (created)
   ├── modules/
   │   ├── security/
   │   │   ├── main.tf
   │   │   └── templates/
   │   ├── claude-code/
   │   │   ├── main.tf
   │   │   └── templates/
   │   └── systemd/
   │       ├── main.tf
   │       └── templates/
   ```

2. Copy the module content from the main README.md

3. Create a terraform.tfvars file with your values

4. Run:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Current Implementation

The current implementation uses shell scripts because:
- They provide more direct control and visibility
- Easier to debug and modify
- Don't require Terraform knowledge
- Can be run step-by-step

The Terraform approach would be better for:
- Managing multiple environments
- State management
- Idempotent operations
- Infrastructure as Code best practices

## Migration Path

To migrate from scripts to Terraform:
1. Import existing resources into Terraform state
2. Gradually replace script functionality with Terraform resources
3. Test thoroughly in a staging environment