#!/bin/bash

# This script tests the Wazuh indexer node installation.
#
# For additional information, please refer to the Wazuh documentation:
#   - https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/index.html
#
# Usage: test-indexer-node.sh
#
#
# Note: Ensure that you have the necessary permissions to execute this script,
#       and that you have `curl` installed on your system and that the 
#       wazuh-install-files are located in the same directory.

# ====
# Start the Wazuh indexer node.
# ====
systemctl daemon-reload
systemctl enable wazuh-indexer
systemctl start wazuh-indexer

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