#!/bin/bash

# This script is used to connect to the Vagrant machine or to the AWS instance.
#
# Usage: connect.sh

file="/inventory.yaml"

# =======
# Extract the parameters
# =======
host=$(grep 'ansible_host:' "$file" | awk '{print $2}')
port=$(grep 'ansible_port:' "$file" | awk '{print $2}')
user=$(grep 'ansible_user:' "$file" | awk '{print $2}')
private_key=$(grep 'ansible_ssh_private_key_file:' "$file" | awk '{print $2}')

# =======
# Connect to the machine
# =======
ssh -i $private_key -p $port -o StrictHostKeyChecking=no ${user}@${host}