#!/bin/bash
# OS Detection and Package Manager Utilities

# Global variables to store detected OS and package manager
OS_TYPE=""
PKG_MANAGER=""

get_os_type() {
    if [[ -n "$OS_TYPE" ]]; then
        echo "$OS_TYPE"
        return
    fi

    if [[ "$(uname -s)" == "Linux" ]]; then
        OS_TYPE="linux"
    elif command -v choco &>/dev/null || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS_TYPE="windows"
    else
        OS_TYPE="unknown"
    fi
    echo "$OS_TYPE"
}

get_package_manager() {
    if [[ -n "$PKG_MANAGER" ]]; then
        echo "$PKG_MANAGER"
        return
    fi

    local current_os
    current_os=$(get_os_type)

    if [[ "$current_os" == "linux" ]]; then
        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt"
        elif command -v yum &>/dev/null; then
            PKG_MANAGER="yum" # Add other Linux pkg managers if needed
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="unknown_linux_pkg_manager"
        fi
    elif [[ "$current_os" == "windows" ]]; then
        if command -v choco &>/dev/null; then
            PKG_MANAGER="choco"
        else
            PKG_MANAGER="unknown_windows_pkg_manager"
        fi
    else
        PKG_MANAGER="unknown"
    fi
    echo "$PKG_MANAGER"
}

# Function to run package update command
run_package_update() {
    local manager
    manager=$(get_package_manager)
    echo "Updating package lists using $manager..."
    case "$manager" in
    apt)
        sudo apt-get update
        ;;
    choco)
        # Choco typically doesn't require a separate update command for package lists before install
        # choco outdated # This lists outdated packages, not quite the same as apt update
        echo "Chocolatey does not require a separate package list update step like apt."
        ;;
    yum)
        sudo yum check-update
        ;;
    dnf)
        sudo dnf check-update
        ;;
    *)
        echo "Warning: Unknown package manager '$manager'. Cannot update package lists."
        return 1
        ;;
    esac
}

# Function to run install command
run_package_install() {
    local manager
    manager=$(get_package_manager)
    local packages_to_install=("$@")

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "No packages specified for installation."
        return 1
    fi

    echo "Installing package(s): ${packages_to_install[*]} using $manager..."
    case "$manager" in
    apt)
        # shellcheck disable=SC2068
        sudo apt-get install -y ${packages_to_install[@]}
        ;;
    choco)
        for pkg in "${packages_to_install[@]}"; do
            # Choco might have different package names, this is a generic attempt
            # Ensure choco is in PATH; PowerShell might be needed for some choco setups.
            choco install "$pkg" -y --no-progress --force
        done
        ;;
    yum)
        # shellcheck disable=SC2068
        sudo yum install -y ${packages_to_install[@]}
        ;;
    dnf)
        # shellcheck disable=SC2068
        sudo dnf install -y ${packages_to_install[@]}
        ;;
    *)
        echo "Warning: Unknown package manager '$manager'. Cannot install packages: ${packages_to_install[*]}"
        return 1
        ;;
    esac
}

# Helper to check for sudo on Linux for scripts that need it initially
ensure_sudo_linux() {
    local current_os
    current_os=$(get_os_type)
    if [[ "$current_os" == "linux" ]]; then
        if ! command -v sudo &>/dev/null; then
            echo "ERROR: sudo command not found on Linux. Please install sudo."
            exit 1
        fi
        if ! sudo -v &>/dev/null; then
            echo "ERROR: Current user does not have sudo privileges or password timed out on Linux."
            echo "Please run 'sudo -v' first or configure sudoers."
            exit 1
        fi
        echo "Sudo privileges confirmed for Linux."
    fi
}

# Export functions if sourced, or allow execution for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "OS Detection Script (for testing)"
    detected_os=$(get_os_type)
    echo "Detected OS Type: $detected_os"
    detected_pm=$(get_package_manager)
    echo "Detected Package Manager: $detected_pm"

    if [[ "$detected_os" == "linux" ]]; then ensure_sudo_linux; fi

    echo "
Simulating package update:"
    run_package_update
    echo "
Simulating package install (e.g., curl, though it's likely already present):"
    run_package_install "curl"
fi
