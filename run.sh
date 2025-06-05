#!/bin/bash
# Claude Code Infrastructure Launcher
# This is a convenience script to run the orchestrator from the project root

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch the orchestrator
exec "$SCRIPT_DIR/scripts/phases/run.sh" "$@"