#!/bin/bash

# Prompt the user for GitHub Token and artifact details securely
if [ -z "$GITHUB_TOKEN" ]; then
  read -rsp 'Enter GitHub Token: ' GITHUB_TOKEN
  echo ""
fi
export GITHUB_TOKEN

if [ -z "$RUN_ID" ]; then
  read -rp 'Enter Action Run ID: ' RUN_ID
fi
export RUN_ID

if [ -z "$ARTIFACT_NAME" ]; then
  read -rp 'Enter Artifact Name: ' ARTIFACT_NAME
fi
export ARTIFACT_NAME

# Define environment variables with default values if not provided
read -rp "Enter current node name (default: 'node-1'): " NODE_NAME
export NODE_NAME=${NODE_NAME:-"node-1"}

IP_ADDRESS=$(ip addr show eth1 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="127.0.0.1"
fi
read -rp "Enter IP of current node (default: '$IP_ADDRESS'): " NODE_IP
export NODE_IP=${NODE_IP:-$IP_ADDRESS}

export CERTS_PATH=${CERTS_PATH:-"/home/vagrant/wazuh-certificates.tar"}

# Optional variables for Node 2
read -rp 'Enter secondary Node name (optional): ' NODE_2
read -rp 'Enter IP of secondary Node (optional): ' IP_NODE_2

# Logging function with timestamps
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Function to run a command and check for errors
run_command() {
  local cmd=$1
  log "Executing: $cmd"
  if ! eval "$cmd"; then
    log "Error executing: $cmd"
    exit 1
  else
    log "Successfully executed: $cmd"
  fi
}

# Main execution
log "Starting the script execution"

run_command "bash 01_download_and_install_package.sh -id $RUN_ID -n $ARTIFACT_NAME"

# Apply certificates
if [ -n "$NODE_2" ] && [ -n "$IP_NODE_2" ]; then
  run_command "sudo bash 02_apply_certificates.sh -p $CERTS_PATH -n $NODE_NAME -nip $NODE_IP -s $NODE_2 -sip $IP_NODE_2"
else
  run_command "sudo bash 02_apply_certificates.sh -p $CERTS_PATH -n $NODE_NAME -nip $NODE_IP"
fi

# Start indexer service
run_command "sudo bash 03_manage_indexer_service.sh -a start"

# Initialize cluster (assumes this step doesn't depend on Node 2 presence)
run_command "sudo bash 04_initialize_cluster.sh"
sleep 10

# Validate installed plugins
if [ -n "$NODE_2" ]; then
  run_command "bash 05_validate_installed_plugins.sh -n $NODE_NAME -n $NODE_2"
else
  run_command "bash 05_validate_installed_plugins.sh -n $NODE_NAME"
fi

# Validate setup and command manager
run_command "bash 06_validate_setup.sh"
run_command "bash 07_validate_command_manager.sh"

# Uninstall indexer
log "Running 08_uninstall_indexer.sh"
run_command "sudo bash 08_uninstall_indexer.sh"

log "All tasks completed successfully."
