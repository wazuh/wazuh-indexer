#!/bin/bash

# This script downloads and sets up a Wazuh indexer node.
#
# For additional information, please refer to the Wazuh documentation:
#   - https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/index.html
#
# Usage: setup-wazuh.sh [version]
#
# Arguments:
# - version        [required] The version of Wazuh to install (e.g., 4.11.0).
#
# Note: Ensure that you have the necessary permissions to execute this script,
#       and that you have `curl` installed on your system.

if [ -z "$1" ]; then
    echo "Error: Version argument is required."
    exit 1
fi

version=$1

# ====
# Download the Wazuh files.
# ====
curl -sO https://packages.wazuh.com/$version/wazuh-install.sh
curl -sO https://packages.wazuh.com/$version/config.yml

# ====
# Configure config.yml file.
# ====
cat <<EOL > config.yml
nodes:
  indexer:
    - name: node-1
      ip: "127.0.0.1"
EOL

# ====
# Install Wazuh indexer node.
# ====
bash wazuh-install.sh --generate-config-files
bash wazuh-install.sh --wazuh-indexer node-1
bash wazuh-install.sh --start-cluster

# ====
# Get the admin password.
# ====
password=$(tar -axf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt -O | grep -P "\'admin\'" -A 1 | tail -n 1 | tr -d '[:space:]' | sed "s/.*'\(.*\)'.*/\1/")

# ====
# Checks if the response is correct.
# ====
response=$(curl -k -u admin:$password https://127.0.0.1:9200)
if echo "$response" | grep -q '"name" : "node-1"'; then
    exit 0
else
    exit 1
fi