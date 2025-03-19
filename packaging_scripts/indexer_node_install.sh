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
curl -sO https://packages.wazuh.com/$1/wazuh-certs-tool.sh
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
bash ./wazuh-certs-tool.sh -A
tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .
rm -rf ./wazuh-certificates

# ====
# Installation based on the package manager.
# ====
if command -v apt-get &> /dev/null; then
   apt-get install debconf adduser procps
   apt-get install gnupg apt-transport-https
   curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
   echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
   apt-get update

   apt-get -y install wazuh-indexer
else
    yum install coreutils
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    echo -e '[wazuh]\ngpgcheck=1\ngpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH\nenabled=1\nname=EL-$releasever - Wazuh\nbaseurl=https://packages.wazuh.com/4.x/yum/\nprotect=1' | tee /etc/yum.repos.d/wazuh.repo
    yum -y install wazuh-indexer
fi

# ====
# Start the Wazuh indexer service.
# ====
sudo systemctl daemon-reload
sudo systemctl enable wazuh-indexer
sudo systemctl start wazuh-indexer