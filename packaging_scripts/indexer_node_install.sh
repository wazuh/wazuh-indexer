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

# ====
# Download the Wazuh files.
# ====
curl -sO https://packages.wazuh.com/$1/wazuh-install.sh
curl -sO https://packages.wazuh.com/$1/config.yml

# ====
# Configure config.yml file.
# ====
cat <<EOL > config.yml
nodes:
  indexer:
    - name: node-1
      ip: "192.168.56.10"
EOL

# ====
# Install Wazuh indexer node.
# ====
bash wazuh-install.sh --generate-config-files
bash wazuh-install.sh --wazuh-indexer node-1