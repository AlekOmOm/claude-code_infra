#!/bin/bash
# Phase 1: Prerequisites for Your Control Machine

echo "Phase 1: Checking Prerequisites for Your Control Machine..."
echo "---------------------------------------------------------"

failed_tools=()
tools_to_install_args=""

# Function to check command and print status
check_command() {
    local cmd_name=$1
    local cmd_arg_for_installer=$2 # Argument to pass to installer script, e.g., "terraform"
    local version_arg=$3
    local required_version_msg=$4
    local check_passed=true

    echo -n "Checking for $cmd_name... "
    if command -v "$cmd_name" &>/dev/null; then
        echo -n "Installed. "
        if [ -n "$version_arg" ]; then
            local version
            version=$(eval "$cmd_name $version_arg" 2>&1)
            echo -n "Version: $version" # Keep on one line for now
            if [[ "$cmd_name" == "terraform" ]]; then
                current_version_num=$(echo "$version" | head -n1 | sed -n 's/Terraform v\([0-9.]*\).*/\1/p')
                required_version_num="1.5.0"
                if ! printf '%s\n%s\n' "$required_version_num" "$current_version_num" | sort -V -C &>/dev/null; then
                    echo "" # Newline before error
                    echo "  └─ ${required_version_msg:-Terraform version $required_version_num or higher is required.}"
                    echo "     Current version: $current_version_num. Please update."
                    check_passed=false
                else
                    echo " (OK >= $required_version_num)" # Confirmation on same line
                fi
            else
                echo "" # Newline if not terraform and version arg was present
            fi
        else
            echo "" # Newline if no version check
        fi
    else
        echo "Not found."
        check_passed=false
    fi

    if ! $check_passed; then
        echo "  └─ Failed: $cmd_name ${required_version_msg:-is required.}"
        # Avoid duplicate additions, especially for node/npm
        if [[ "$cmd_arg_for_installer" == "node" ]]; then
            if ! [[ " ${failed_tools[@]} " =~ " node " ]]; then
                failed_tools+=("node")
            fi
        elif ! [[ " ${failed_tools[@]} " =~ " $cmd_arg_for_installer " ]]; then
            failed_tools+=("$cmd_arg_for_installer")
        fi
        return 1 # Failure
    fi
    return 0 # Success
}

# Perform checks
check_command "terraform" "terraform" "--version" "Terraform v1.5.0 or higher is required."
check_command "node" "node" "--version" "Node.js (LTS recommended, e.g., 20.x)."
check_command "npm" "node" "--version" "npm (comes with Node.js)." # Installing node should bring npm
check_command "git" "git" "--version" "Git."
check_command "gh" "gh" "--version" "GitHub CLI (gh)."

echo "---------------------------------------------------------"

if [ ${#failed_tools[@]} -eq 0 ]; then
    echo "✅ All prerequisite checks passed."
    echo "Ensure you have also cloned or downloaded the claude-code_infra project files."
else
    echo "❌ Some prerequisite checks failed for the following tools:"
    for tool in "${failed_tools[@]}"; do
        echo "   - $tool"
    done
    echo ""
    read -r -p "Attempt to install/update these missing tools? (Y/n): " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ || -z "$response" ]]; then
        echo "Proceeding with installation..."
        install_script_path="./scripts/implementation/1_install-prerequisites.sh"

        if [ ! -f "$install_script_path" ]; then
            echo "ERROR: Installation script not found at $install_script_path"
            exit 1
        fi
        if [ ! -x "$install_script_path" ]; then
            echo "ERROR: Installation script at $install_script_path is not executable. Please run: chmod +x $install_script_path"
            exit 1
        fi

        for tool_arg in "${failed_tools[@]}"; do
            tools_to_install_args+=" --install-$tool_arg"
        done

        echo "Executing: $install_script_path$tools_to_install_args"
        eval "$install_script_path$tools_to_install_args"

        echo "---------------------------------------------------------"
        echo "Please re-run this check script (1_prerequisites_check.sh) after installation to verify."
    else
        echo "Installation skipped. Please install the missing tools manually before proceeding."
    fi
fi
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/1_prerequisites_check.sh
