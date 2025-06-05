terraform {
  required_version = ">= 1.5"
  
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

# Variables
variable "target_server_ip" {
  description = "IP address of the target server"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API Key"
  type        = string
  sensitive   = true
}

variable "claude_user" {
  description = "Username for Claude Code user"
  type        = string
  default     = "claude-user"
}

variable "enable_mcp_server" {
  description = "Enable MCP server"
  type        = bool
  default     = true
}

variable "mcp_server_port" {
  description = "Port for MCP server"
  type        = number
  default     = 3000
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

# Locals
locals {
  ssh_public_key = file(var.ssh_public_key_path)
}

# Security Module
module "security" {
  source = "./modules/security"
  
  claude_user        = var.claude_user
  ssh_public_key     = local.ssh_public_key
  target_server_ip   = var.target_server_ip
  ssh_port          = var.ssh_port
  mcp_server_port   = var.mcp_server_port
  enable_mcp_server = var.enable_mcp_server
}

# Claude Code Module
module "claude_code" {
  source = "./modules/claude-code"
  
  claude_user          = var.claude_user
  github_token        = var.github_token
  anthropic_api_key   = var.anthropic_api_key
  target_server_ip    = var.target_server_ip
  
  depends_on = [module.security]
}

# Systemd Services Module
module "systemd" {
  source = "./modules/systemd"
  
  claude_user          = var.claude_user
  enable_mcp_server   = var.enable_mcp_server
  mcp_server_port     = var.mcp_server_port
  anthropic_api_key   = var.anthropic_api_key
  target_server_ip    = var.target_server_ip
  
  depends_on = [module.claude_code]
}

# Outputs
output "claude_server_ip" {
  value = var.target_server_ip
}

output "ssh_connection" {
  value = "ssh ${var.claude_user}@${var.target_server_ip}"
}

output "deployment_complete" {
  value = "Claude Code Infrastructure deployed successfully!"
}