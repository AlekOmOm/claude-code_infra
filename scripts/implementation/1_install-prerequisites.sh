#!/bin/bash
set -euo pipefail

# Implementation script to install prerequisites
# This script expects to be called with flags indicating which tools to install,
# e.g., --install-terraform --install-node

# Source the OS utilities script
OS_UTILS_PATH="$(dirname "${BASH_SOURCE[0]}")/os_utils.sh"
if [ ! -f "$OS_UTILS_PATH" ]; then
    echo "ERROR: OS Utilities script not found at $OS_UTILS_PATH"
    exit 1
fi
# shellcheck source=./os_utils.sh
source "$OS_UTILS_PATH"

# Function to check if sudo is available and user has sudo rights
check_sudo() {
    if ! command -v sudo &>/dev/null; then
        echo "ERROR: sudo command not found. Please install sudo or run this script as root."
        exit 1
    fi
    if ! sudo -v &>/dev/null; then
        echo "ERROR: Current user does not have sudo privileges or password timed out."
        echo "Please run 'sudo -v' first or ensure you can run sudo commands without a password prompt if automating."
        exit 1
    fi
}

install_terraform() {
    echo "Attempting to install Terraform..."
    local current_os pkg_mgr
    current_os=$(get_os_type)
    pkg_mgr=$(get_package_manager)

    if command -v terraform &>/dev/null; then
        current_version_num=$(terraform --version | head -n1 | sed -n 's/Terraform v\([0-9.]*\).*/\1/p')
        required_version_num="1.5.0"
        if printf '%s\n%s\n' "$required_version_num" "$current_version_num" | sort -V -C &>/dev/null; then
            echo "Terraform is already installed and meets version requirements (>= $required_version_num). Version: $current_version_num. Skipping."
            return
        else
            echo "Terraform is installed but version ($current_version_num) is older than required ($required_version_num). Attempting upgrade/reinstall."
        fi
    fi

    if [[ "$current_os" == "linux" && "$pkg_mgr" == "apt" ]]; then
        run_package_update
        run_package_install gnupg software-properties-common curl
        echo "Adding HashiCorp GPG key and repository..."
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" -y
        run_package_update
        run_package_install terraform
    elif [[ "$current_os" == "windows" && "$pkg_mgr" == "choco" ]]; then
        echo "Attempting to install Terraform using Chocolatey..."
        run_package_install terraform
    else
        echo "Automated Terraform installation is primarily set up for Linux (apt) or Windows (choco)."
        echo "For OS: $current_os with Pkg Mgr: $pkg_mgr, please install Terraform manually (version >= 1.5.0)."
        return 1
    fi
    echo "Terraform installation/update attempt finished. Verify with 'terraform --version'."
}

install_node() {
    echo "Attempting to install Node.js (LTS 20.x) and npm..."
    local current_os pkg_mgr
    current_os=$(get_os_type)
    pkg_mgr=$(get_package_manager)

    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        echo "Node.js and npm seem to be installed. Node version: $(node --version), npm version: $(npm --version). Skipping re-installation."
        return
    fi

    if [[ "$current_os" == "linux" && "$pkg_mgr" == "apt" ]]; then
        run_package_update
        run_package_install curl
        echo "Setting up NodeSource repository for Node.js 20.x..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        run_package_install nodejs
    elif [[ "$current_os" == "windows" && "$pkg_mgr" == "choco" ]]; then
        echo "Attempting to install Node.js LTS using Chocolatey..."
        run_package_install nodejs-lts # Choco usually has an LTS package
    else
        echo "Automated Node.js installation is primarily set up for Linux (apt) or Windows (choco)."
        echo "For OS: $current_os with Pkg Mgr: $pkg_mgr, please install Node.js (LTS 20.x) and npm manually."
        return 1
    fi
    echo "Node.js and npm installation attempt finished. Verify with 'node --version' and 'npm --version'."
}

install_git() {
    echo "Attempting to install Git..."
    if command -v git &>/dev/null; then
        echo "Git is already installed. Version: $(git --version). Skipping."
        return
    fi
    run_package_update
    run_package_install git
    echo "Git installation attempt finished. Verify with 'git --version'."
}

install_gh() {
    echo "Attempting to install GitHub CLI (gh)..."
    local current_os pkg_mgr
    current_os=$(get_os_type)
    pkg_mgr=$(get_package_manager)

    if command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) is already installed. Version: $(gh --version). Skipping."
        return
    fi

    if [[ "$current_os" == "linux" && "$pkg_mgr" == "apt" ]]; then
        run_package_update
        run_package_install curl gpg
        echo "Adding GitHub CLI GPG key and repository..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        run_package_update
        run_package_install gh
    elif [[ "$current_os" == "windows" && "$pkg_mgr" == "choco" ]]; then
        echo "Attempting to install GitHub CLI (gh) using Chocolatey..."
        run_package_install gh
    else
        echo "Automated GitHub CLI installation is primarily set up for Linux (apt) or Windows (choco)."
        echo "For OS: $current_os with Pkg Mgr: $pkg_mgr, please install GitHub CLI (gh) manually."
        return 1
    fi
    echo "GitHub CLI (gh) installation attempt finished. Verify with 'gh --version'."
}

install_gcloud() {
    echo "Attempting to install Google Cloud CLI (gcloud)..."
    local current_os pkg_mgr
    current_os=$(get_os_type)
    pkg_mgr=$(get_package_manager)

    if command -v gcloud &>/dev/null; then
        echo "Google Cloud CLI (gcloud) is already installed. Version: $(gcloud --version | head -n1). Skipping."
        return
    fi

    if [[ "$current_os" == "linux" && "$pkg_mgr" == "apt" ]]; then
        run_package_update
        run_package_install curl gpg
        echo "Adding Google Cloud CLI GPG key and repository..."
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        run_package_update
        run_package_install google-cloud-cli
        echo "Installing additional components..."
        run_package_install google-cloud-cli-gke-gcloud-auth-plugin
    elif [[ "$current_os" == "windows" && "$pkg_mgr" == "choco" ]]; then
        echo "Attempting to install Google Cloud CLI using Chocolatey..."
        run_package_install gcloudsdk
    else
        echo "Automated Google Cloud CLI installation is primarily set up for Linux (apt) or Windows (choco)."
        echo "For OS: $current_os with Pkg Mgr: $pkg_mgr, please install Google Cloud CLI manually."
        echo "Download from: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
    echo "Google Cloud CLI (gcloud) installation attempt finished. Verify with 'gcloud --version'."
    echo "Next steps:"
    echo "  1. Run: gcloud auth login"
    echo "  2. Run: gcloud config set project YOUR_PROJECT_ID"
}

# Check for sudo privileges early if on Linux
ensure_sudo_linux

# Parse arguments
if [ "$#" -eq 0 ]; then
    echo "No tools specified for installation. Usage: $0 --install-terraform --install-node etc."
    exit 1
fi

for arg in "$@"; do
    case $arg in
    --install-terraform)
        install_terraform
        shift
        ;;
    --install-node)
        install_node # This will also install npm
        shift
        ;;
    --install-git)
        install_git
        shift
        ;;
    --install-gh)
        install_gh
        shift
        ;;
    --install-gcloud)
        install_gcloud
        shift
        ;;
    *)
        echo "Warning: Unknown argument $arg"
        shift
        ;;
    esac
done

echo "All specified installation attempts are complete."
