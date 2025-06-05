#!/bin/bash
# Utilities for managing .env files

# Default .env file path, can be overridden by functions if needed
ENV_FILE_PATH=".env"
ENV_TEMPLATE_PATH=".env.template"

# Ensure .env file exists, copying from .env.template if necessary
# Usage: ensure_env_file [target_env_file]
ensure_env_file() {
    local target_env_file=${1:-$ENV_FILE_PATH}
    local template_file=${ENV_TEMPLATE_PATH}

    if [ ! -f "$target_env_file" ]; then
        if [ -f "$template_file" ]; then
            cp "$template_file" "$target_env_file"
            echo "Initialized $target_env_file from $template_file."
            echo "Please review and fill in $target_env_file."
            return 0
        else
            echo "Warning: $template_file not found. Cannot initialize $target_env_file automatically." >&2
            echo "Please create $target_env_file manually or ensure $template_file exists." >&2
            # Touch the file so subsequent operations might not fail on file not found, but it will be empty.
            touch "$target_env_file"
            return 1
        fi
    fi
    return 0 # File already exists
}

# Get a value from the .env file for a given key
# Usage: get_env_value KEY [default_value] [env_file_path]
get_env_value() {
    local key="$1"
    local default_value="${2:-}" # Optional default value
    local file_path="${3:-$ENV_FILE_PATH}"
    local value=""

    if [ ! -f "$file_path" ]; then
        # echo "Warning: $file_path not found. Returning default value for $key." >&2
        echo "$default_value"
        return
    fi

    # Read file, filter for key, and extract value
    # Handles cases with or without quotes, and comments
    value=$(grep -E "^\s*$key\s*=" "$file_path" | grep -v '^#' | sed -n 's/^\s*[^=]*=\(.*\)/\1/p' | sed 's/^[[:space:]"]*//;s/[[:space:]"]*$//')

    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Update or add a key-value pair in the .env file
# Usage: update_env_value KEY VALUE [env_file_path]
update_env_value() {
    local key="$1"
    local new_value="$2"
    local file_path="${3:-$ENV_FILE_PATH}"

    if [ ! -f "$file_path" ]; then
        # Try to ensure it exists, especially if called directly without prior ensure_env_file
        if ! ensure_env_file "$file_path"; then
            echo "Error: $file_path does not exist and could not be created. Cannot update $key." >&2
            return 1
        fi
    fi

    # Escape special characters in new_value for sed (especially / and &)
    local escaped_new_value
    escaped_new_value=$(printf '%s' "$new_value" | sed -e 's/[\\/&]/\\&/g')

    # Check if key exists (and is not commented out)
    if grep -qE "^\s*$key\s*=" "$file_path" && ! grep -qE "^\s*#\s*$key\s*=" "$file_path"; then
        # Key exists, update it. Handles optional quotes around value.
        # Using a temporary file for robust in-place editing with sed
        sed "s|^\s*\($key\s*=\s*\).*$|\1\"$escaped_new_value\"|" "$file_path" >"$file_path.tmp" && mv "$file_path.tmp" "$file_path"
    else
        # Key doesn't exist or is commented out, append it
        echo "$key=\"$new_value\"" >>"$file_path"
    fi
    # echo "Updated $key in $file_path to \"$new_value\""
}

# Check if all specified required keys are set (not empty and not placeholders)
# Usage: check_required_env_vars "KEY1" "KEY2_PLACEHOLDER" "KEY3"
# Placeholders should be the exact string used in .env.template, e.g., "YOUR_SERVER_IP_HERE"
check_required_env_vars() {
    local file_path="${1:-$ENV_FILE_PATH}"
    shift # Remove file_path from arguments, rest are keys or key=placeholder pairs
    local all_vars_set=true

    if [ ! -f "$file_path" ]; then
        echo "Error: $file_path not found. Cannot check required variables." >&2
        return 1 # Indicates failure
    fi

    for key_or_pair in "$@"; do
        local key placeholder
        if [[ "$key_or_pair" == *"="* ]]; then
            key=$(echo "$key_or_pair" | cut -d'=' -f1)
            placeholder=$(echo "$key_or_pair" | cut -d'=' -f2-)
        else
            key="$key_or_pair"
            placeholder=""
        fi

        local value
        value=$(get_env_value "$key" "" "$file_path")

        if [ -z "$value" ]; then
            echo "Error: Required environment variable '$key' is not set in $file_path." >&2
            all_vars_set=false
        elif [ -n "$placeholder" ] && [ "$value" == "$placeholder" ]; then
            echo "Error: Required environment variable '$key' in $file_path is still set to its placeholder value ('$placeholder')." >&2
            all_vars_set=false
        fi
    done

    if $all_vars_set; then
        return 0 # Success
    else
        return 1 # Failure
    fi
}

# Self-test section when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running self-tests for env_utils.sh..."
    TEST_ENV_FILE=".env.test_temp"
    cp .env.template "$TEST_ENV_FILE" # Start with a template

    echo "
Test 1: ensure_env_file (first time)"
    ensure_env_file "$TEST_ENV_FILE"
    ls -l "$TEST_ENV_FILE"

    echo "
Test 2: get_env_value (initial placeholder)"
    val=$(get_env_value "TARGET_SERVER_IP" "" "$TEST_ENV_FILE")
    echo "TARGET_SERVER_IP is: '$val' (Expected: YOUR_SERVER_IP_HERE)"

    echo "
Test 3: update_env_value (new value)"
    update_env_value "TARGET_SERVER_IP" "192.168.0.100" "$TEST_ENV_FILE"
    val=$(get_env_value "TARGET_SERVER_IP" "" "$TEST_ENV_FILE")
    echo "TARGET_SERVER_IP is now: '$val' (Expected: 192.168.0.100)"

    echo "
Test 4: update_env_value (add new key)"
    update_env_value "NEW_TEST_KEY" "Hello World" "$TEST_ENV_FILE"
    val=$(get_env_value "NEW_TEST_KEY" "" "$TEST_ENV_FILE")
    echo "NEW_TEST_KEY is: '$val' (Expected: Hello World)"
    grep "NEW_TEST_KEY" "$TEST_ENV_FILE"

    echo "
Test 5: update_env_value (value with spaces and some special chars)"
    update_env_value "SPACED_KEY" "Value with spaces & /slashes/" "$TEST_ENV_FILE"
    val=$(get_env_value "SPACED_KEY" "" "$TEST_ENV_FILE")
    echo "SPACED_KEY is: '$val' (Expected: Value with spaces & /slashes/)"
    grep "SPACED_KEY" "$TEST_ENV_FILE"

    echo "
Test 6: check_required_env_vars (some missing/placeholders)"
    echo "--- Current $TEST_ENV_FILE content ---"
    cat "$TEST_ENV_FILE"
    echo "-------------------------------------"
    if check_required_env_vars "$TEST_ENV_FILE" \
        "TARGET_SERVER_IP" \
        "GITHUB_PAT=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE" \
        "ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY_HERE" \
        "NON_EXISTENT_KEY"; then
        echo "Check passed (unexpected)"
    else
        echo "Check failed as expected."
    fi

    echo "
Test 7: check_required_env_vars (all set)"
    update_env_value "GITHUB_PAT" "ghp_testtoken" "$TEST_ENV_FILE"
    update_env_value "ANTHROPIC_API_KEY" "sk-anth-testkey" "$TEST_ENV_FILE"
    if check_required_env_vars "$TEST_ENV_FILE" \
        "TARGET_SERVER_IP" \
        "GITHUB_PAT=YOUR_GITHUB_PERSONAL_ACCESS_TOKEN_HERE" \
        "ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY_HERE"; then
        echo "Check passed as expected."
    else
        echo "Check failed (unexpected)"
    fi

    rm "$TEST_ENV_FILE"
    echo "
Self-tests complete. Cleaned up $TEST_ENV_FILE."
fi
