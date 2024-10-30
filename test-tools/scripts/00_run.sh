#!/bin/bash

# Prompt the user for GitHub Token and artifact details securely
if [ -z "$GITHUB_TOKEN" ]; then
  read -sp 'Enter GitHub Token: ' GITHUB_TOKEN
  echo ""
fi
export GITHUB_TOKEN

if [ -z "$ARTIFACT_ID" ]; then
  read -p 'Enter Artifact ID: ' ARTIFACT_ID
fi
export ARTIFACT_ID

if [ -z "$ARTIFACT_NAME" ]; then
  read -p 'Enter Artifact Name: ' ARTIFACT_NAME
fi
export ARTIFACT_NAME

# Define environment variables with default values if not provided
export NODE_1=${NODE_1:-"node-1"}
export IP_NODE_1=${IP_NODE_1:-"192.168.56.10"}
export CERTS_PATH=${CERTS_PATH:-"/home/vagrant/wazuh-certificates.tar"}

# Optional variables for Node 2
read -p 'Enter Node 2 (optional): ' NODE_2
read -p 'Enter IP of Node 2 (optional): ' IP_NODE_2

# Logging function with timestamps
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Function to run a command and check for errors
run_command() {
  local cmd=$1
  log "Executing: $cmd"
  eval "$cmd"
  if [ $? -ne 0 ]; then
    log "Error executing: $cmd"
    exit 1
  else
    log "Successfully executed: $cmd"
  fi
}

# Main execution
log "Starting the script execution"

run_command "bash 01_download_and_install_package.sh -id $ARTIFACT_ID -n $ARTIFACT_NAME"

# Apply certificates
if [ -n "$NODE_2" ] && [ -n "$IP_NODE_2" ]; then
  run_command "sudo bash 02_apply_certificates.sh -p $CERTS_PATH -n $NODE_1 -nip $IP_NODE_1 -s $NODE_2 -sip $IP_NODE_2"
else
  run_command "sudo bash 02_apply_certificates.sh -p $CERTS_PATH -n $NODE_1 -nip $IP_NODE_1"
fi

# Start indexer service
run_command "sudo bash 03_manage_indexer_service.sh -a start"

# Initialize cluster (assumes this step doesn't depend on Node 2 presence)
run_command "sudo bash 04_initialize_cluster.sh"

# Validate installed plugins
if [ -n "$NODE_2" ]; then
  run_command "bash 05_validate_installed_plugins.sh -n $NODE_1 -n $NODE_2"
else
  run_command "bash 05_validate_installed_plugins.sh -n $NODE_1"
fi

# Validate setup and command manager
run_command "bash 06_validate_setup.sh"
run_command "bash 07_validate_command_manager.sh"

# Uninstall indexer
log "Running 08_uninstall_indexer.sh"
run_command "sudo bash 08_uninstall_indexer.sh"

log "All tasks completed successfully."
