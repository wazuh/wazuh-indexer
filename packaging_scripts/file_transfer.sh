#!/bin/bash

# This script is used to copy a file to the Vagrant machine or to the AWS instance.
# 
# Usage: send_artifact.sh [file_to_copy]
#
# Arguments:
# - file_to_copy   [required] The file to be copied to the Vagrant machine or AWS instance.

if [ -z "$1" ]; then
    echo "Error: File to be copied argument is required."
    exit 1
fi


destination="/tmp/inventory.yaml"

# =====
# Extract the parameters
# ======
host=$(grep 'ansible_host:' "$destination" | awk '{print $2}' )
port=$(grep 'ansible_port:' "$destination" | awk '{print $2}' )
user=$(grep 'ansible_user:' "$destination" | awk '{print $2}' )
private_key=$(grep 'ansible_ssh_private_key_file:' "$destination" | awk '{print $2}' )

# ======
# Copy the file to the machine
# ======
sudo scp -i $private_key -P $port -o StrictHostKeyChecking=no $1 ${user}@${host}:~
