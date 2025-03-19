#!/bin/bash

# This script downloads and sets up a Wazuh indexer node.
#
# For additional information, please refer to the Wazuh documentation:
#   - https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/index.html
#
# Usage: indexer_node_install.sh [version]
#
# Arguments:
# - version        [required] The version of Wazuh to install (e.g., 4.11.1).
#
# Note: Ensure that you have the necessary permissions to execute this script,
#       and that you have `curl` installed on your system.

if [ -z "$1" ]; then
    echo "Error: Version argument is required."
    exit 1
fi

# ====
# Add the Wazuh repository.
# ====
if command -v apt-get &> /dev/null; then
   apt-get install gnupg apt-transport-httpsç
   curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
   echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list

   apt-get update
else
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    echo -e '[wazuh]\ngpgcheck=1\ngpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH\nenabled=1\nname=EL-$releasever - Wazuh\nbaseurl=https://packages.wazuh.com/4.x/yum/\nprotect=1' | tee /etc/yum.repos.d/wazuh.repo
fi

# ====
# Install Wazuh indexer.
# ====
if command -v apt-get &> /dev/null; then
    apt-get -y install wazuh-indexer=$1-1
else
    yum -y install wazuh-indexer-$1-1
fi