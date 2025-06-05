# Claude Code Infrastructure Deployment Scripts

This directory contains scripts designed to provide an easy and interactive terminal-based experience for deploying the Claude Code agent onto a dedicated Ubuntu server. The deployment process creates a dedicated user and a sandboxed environment for the agent.

## Overall Goal

The primary goal is to simplify the complex process of setting up a secure and functional Claude Code environment. Users should be able to follow a sequence of interactive scripts that guide them through configuration, deployment, and verification with minimal manual intervention outside of providing necessary information and making key decisions.

## Script Organization

The scripts are organized into two main subdirectories:

-   **`scripts/phases/`**: These are the primary, user-facing scripts. Each script corresponds to a distinct phase of the deployment lifecycle. Users will execute these scripts sequentially.
-   **`scripts/implementation/`**: These are backend or utility scripts that are typically called by the phase scripts. They handle specific, often more complex, actions like installing software, manipulating environment files, or attempting automated fixes on the server. Users generally do not run these directly.

## User Experience & Workflow

The deployment process is designed to be a guided, step-by-step experience primarily driven through the terminal:

1.  **Central Configuration (`.env` file)**: The system uses a central `.env` file to store all necessary configurations. This file is initialized from `.env.template` during Phase 1.

2.  **Sequential Phase Execution**: The user navigates through the deployment by running the phase scripts in order:
    *   `./scripts/phases/1_prerequisites_check.sh`
    *   `./scripts/phases/2_information_gathering_input.sh`
    *   `./scripts/phases/3_deployment_configuration_input.sh`
    *   `./scripts/phases/4_execute_deployment.sh` (This was previously `4_execute_deployment_template.sh` - the name implies more direct action now)
    *   `./scripts/phases/5_post_deployment_verification.sh`

3.  **Interactive Input**: 
    *   **Phase 1 (`1_prerequisites_check.sh`)**: Checks for necessary software on the control machine (e.g., Terraform, Node.js, Git, GitHub CLI). If prerequisites are missing, it can optionally call an implementation script (`1_install-prerequisites.sh`) to attempt installation.
    *   **Phase 2 (`2_information_gathering_input.sh`)**: Interactively prompts the user for essential information (e.g., server IP, SSH key path, GitHub PAT, Anthropic API key). These values are then saved to the `.env` file using `env_utils.sh`.
    *   **Phase 3 (`3_deployment_configuration_input.sh`)**: Interactively prompts the user for deployment choices (e.g., Claude service user name, deployment mode, whether to enable the MCP server). These choices are also saved to the `.env` file.

4.  **Configuration Finalization**: After Phases 1-3, the `.env` file should contain all necessary user-provided configurations.

5.  **Deployment Execution (Phase 4 - `4_execute_deployment.sh`)**:
    *   This script first validates the `.env` file, ensuring all required variables are present and not just placeholders.
    *   It then loads variables from `.env`.
    *   It constructs the command to execute the main infrastructure deployment script (`scripts/src/deploy_claude_infrastructure.sh` - *assuming the main script is moved or named this way for clarity*).
    *   The user is shown the final command and prompted for confirmation before execution. The actual deployment to the server happens here.

6.  **Verification (Phase 5 - `5_post_deployment_verification.sh`)**:
    *   After deployment, this script performs a series of checks (some local, some via SSH to the server) to verify that services are running, the firewall is configured, etc.
    *   If common remediable issues are found (e.g., a service isn't active), it can optionally call an implementation script (`5_attempt_post_deployment_fixes.sh`) to try and resolve them on the server.

## Key Scripts & Their Purpose

### `scripts/phases/`

*   **`1_prerequisites_check.sh`**: 
    *   Checks if all required tools (Terraform, Node, npm, git, gh) are installed on the machine running the deployment.
    *   Offers to run `implementation/1_install-prerequisites.sh` if any are missing.
    *   Initializes the `.env` file from `.env.template` if it doesn't exist.
*   **`2_information_gathering_input.sh`**: 
    *   Interactively prompts for server IP, SSH key path, GitHub PAT, and Anthropic API key.
    *   Saves these inputs into the `.env` file.
*   **`3_deployment_configuration_input.sh`**: 
    *   Interactively prompts for Claude user name, deployment mode, and MCP server enablement.
    *   Saves these configurations into the `.env` file.
*   **`4_execute_deployment.sh`**: (Assumed new name for `4_execute_deployment_template.sh`)
    *   Loads configuration from `.env`.
    *   Verifies that all required `.env` variables are set.
    *   Constructs and displays the command to run the main deployment script (`scripts/src/deploy_claude_infrastructure.sh`).
    *   Asks for user confirmation before executing the main deployment.
*   **`5_post_deployment_verification.sh`**: 
    *   Runs various checks on the deployed server (services, firewall, etc.) via SSH.
    *   Offers to run `implementation/5_attempt_post_deployment_fixes.sh` for common issues.

### `scripts/implementation/` (Examples)

*   **`env_utils.sh`**: Contains utility functions for reading from, writing to, and validating the `.env` file. Sourced by phase scripts.
*   **`os_utils.sh`**: Contains utility functions to detect the operating system and appropriate package manager (e.g., apt, choco). Used by installation scripts.
*   **`1_install-prerequisites.sh`**: Attempts to install missing software identified by `phases/1_prerequisites_check.sh`.
*   **`5_attempt_post_deployment_fixes.sh`**: Attempts to fix common issues on the server (e.g., start services) identified by `phases/5_post_deployment_verification.sh`.

### Main Deployment Logic

*   The actual infrastructure provisioning is handled by Terraform configurations (presumably in a `tf/` or similar directory) and the main deployment script (e.g., `scripts/src/deploy_claude_infrastructure.sh`), which is invoked by `phases/4_execute_deployment.sh`.

This structured approach aims to make the deployment process transparent, manageable, and as automated as possible while still allowing for user input and control at critical decision points.
