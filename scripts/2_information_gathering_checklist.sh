#!/bin/bash
# Phase 2: Information and Credentials to Gather

echo "Phase 2: Information and Credentials Gathering Checklist"
echo "---------------------------------------------------------"
echo "Please ensure you have the following information and credentials ready:"

echo "
[ ] 1. Target Ubuntu Server Details:"
echo "    [ ] Server IP Address (e.g., 192.168.1.100 or from .env.gcloud)."
echo "    [ ] SSH access confirmed to the target server from this control machine (if manual intervention is ever needed)."

echo "
[ ] 2. SSH Public Key:"
echo "    [ ] Path to your SSH public key file (e.g., ~/.ssh/id_rsa.pub)."

echo "
[ ] 3. GitHub Personal Access Token (PAT):"
echo "    [ ] GitHub PAT with permissions for:"
echo "        [ ] Repository access (clone, push)."
echo "        [ ] Pull request interaction (read, comment, create)."
echo "        [ ] gh auth login capabilities."

echo "
[ ] 4. Anthropic API Key (for PR Review Workflow):"
echo "    [ ] Your Anthropic API Key."
echo "    [ ] This key must be set as a GitHub Secret named 'ANTHROPIC_API_KEY' in the target GitHub repository."

echo "---------------------------------------------------------"
echo "Once all items are checked, you can proceed to configure your deployment."
echo "---------------------------------------------------------"

# Make the script executable: chmod +x scripts/2_information_gathering_checklist.sh
