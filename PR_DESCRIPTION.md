# feat: 🎭 Add intelligent orchestration system for Claude Code deployment

## Summary

This PR introduces a comprehensive orchestration system that streamlines the Claude Code infrastructure deployment process. The new `run.sh` script provides an intelligent, interactive workflow that guides users from initial setup through daily usage.

## Key Features

### 🎯 Main Orchestrator (`scripts/phases/run.sh`)
- Automatically detects configuration completeness and skips unnecessary phases
- Checks deployment status (not deployed, partial, or fully deployed)
- Verifies environment health before offering connection
- Directly launches Claude Code in the correct project directory via SSH

### 🔍 Deployment Status Checking (`deploy_check_utils.sh`)
- Verifies presence of claude-user, Claude Code CLI, systemd services
- Detects partial deployments and offers completion
- Provides detailed component status reporting

### 🏥 Environment Health Monitoring (`remote_environment_check.sh`)
- Monitors service status (claude-code, mcp-server)
- Checks system resources (memory, disk, CPU)
- Validates network connectivity and firewall configuration
- Returns health status: healthy, degraded, or unhealthy

### 🚀 User Experience Improvements
- Single command deployment: `./run.sh` or `make run`
- Intelligent flow that adapts to current state
- Automatic SSH connection and Claude launch when ready
- Clear prompts and status messages throughout

## Usage

```bash
# First time setup
./run.sh
# → Automatically runs through all setup phases
# → Deploys Claude Code
# → Connects you directly to Claude

# Daily use (after deployment)
./run.sh
# → Detects existing deployment
# → Checks health
# → Offers immediate connection
```

## Changes

### New Files
- `scripts/phases/run.sh` - Main orchestration script
- `scripts/implementation/utils/deploy_check_utils.sh` - Deployment status utilities
- `scripts/implementation/utils/remote_environment_check.sh` - Environment health checks
- `run.sh` - Convenience launcher at project root
- `scripts/phases/ORCHESTRATION_README.md` - Detailed orchestration documentation

### Modified Files
- `Makefile` - Added new targets: `run`, `deploy`, `test`, `clean`
- `README.md` - Added Quick Start section highlighting the orchestrator

## Implementation Details

The orchestrator implements a state machine-like flow:

1. **Configuration State**: Checks if `.env` has all required values
   - If incomplete → Run phases 1-3 (prerequisites, info gathering, config)
   - If complete → Skip to deployment check

2. **Deployment State**: Determines current deployment status
   - Not deployed → Offer to deploy
   - Partially deployed → Offer to complete
   - Fully deployed → Check health

3. **Health State**: Verifies environment is ready for use
   - Healthy → Offer immediate connection
   - Degraded/Unhealthy → Run verification and fixes

4. **Connection State**: Direct SSH and Claude launch
   - Connects as claude-user
   - Changes to project directory
   - Launches Claude CLI

## Testing

The orchestrator has been designed to handle various scenarios:
- Fresh installation
- Partial deployments
- Healthy deployments
- Degraded environments
- Missing prerequisites

Each utility script includes self-test functionality when run directly:
```bash
./scripts/implementation/utils/deploy_check_utils.sh
./scripts/implementation/utils/remote_environment_check.sh
```

## Benefits

1. **Reduced Complexity**: Users no longer need to understand the phase system
2. **Intelligent Flow**: Automatically skips completed steps
3. **Error Recovery**: Detects and attempts to fix common issues
4. **One-Command Access**: From setup to daily use with `./run.sh`
5. **Clear Feedback**: Status messages guide users through each step

## Future Enhancements

- Add support for multiple deployment profiles
- Implement backup/restore functionality
- Add performance monitoring dashboard
- Support for cluster deployments

## Related Issues

Closes #[issue-number] - Simplify deployment workflow
Related to #[issue-number] - Improve user experience

## Checklist

- [x] Code follows project style guidelines
- [x] Self-review completed
- [x] Documentation updated
- [x] Scripts are executable and tested
- [x] No sensitive information exposed
- [x] Backward compatibility maintained