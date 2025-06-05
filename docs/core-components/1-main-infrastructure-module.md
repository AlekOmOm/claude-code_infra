# Complete Terraform Infrastructure Configuration

## Main Infrastructure Module

**terraform/main.tf**
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Variables for customization
variable "server_ip" {
  description = "Ubuntu server IP address"
  type        = string
  default     = "192.168.1.100"
}

variable "claude_user" {
  description = "Dedicated user for Claude Code"
  type        = string
  default     = "claude-user"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}

variable "github_token" {
  description = "GitHub token for MCP integration"
  type        = string
  sensitive   = true
}

# Core modules
module "security_hardening" {
  source = "./modules/security"
  
  claude_user    = var.claude_user
  server_ip      = var.server_ip
  ssh_public_key = var.ssh_public_key
}

module "claude_code_setup" {
  source = "./modules/claude-code"
  
  claude_user   = var.claude_user
  github_token  = var.github_token
  depends_on    = [module.security_hardening]
}

module "networking" {
  source = "./modules/networking"
  
  server_ip = var.server_ip
}

module "systemd_services" {
  source = "./modules/systemd"
  
  claude_user = var.claude_user
  depends_on  = [module.claude_code_setup]
}

# Outputs
output "deployment_status" {
  value = {
    claude_user_created = module.security_hardening.user_status
    claude_code_installed = module.claude_code_setup.installation_status
    services_enabled = module.systemd_services.service_status
    firewall_configured = module.networking.firewall_status
  }
}
``` 