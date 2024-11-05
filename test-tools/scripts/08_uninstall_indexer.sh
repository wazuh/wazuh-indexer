#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to display usage help
usage() {
    echo "Usage: $0 [-h]"
    echo
    echo "This script uninstalls Wazuh Indexer and validates its removal."
    echo
    echo "Options:"
    echo "    -h, --help    Show this help message and exit."
    echo
    exit 1
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
else
    echo "Unsupported package manager. Please use a system with apt-get or yum."
    exit 1
fi

# Uninstall Wazuh Indexer
echo "Uninstalling Wazuh Indexer..."
sudo systemctl stop wazuh-indexer > /dev/null 2>&1
sudo systemctl disable wazuh-indexer > /dev/null 2>&1

if [ "$PKG_MANAGER" == "apt-get" ]; then
    sudo apt-get remove --purge wazuh-indexer -y > /dev/null 2>&1
elif [ "$PKG_MANAGER" == "yum" ]; then
    sudo yum remove wazuh-indexer -y > /dev/null 2>&1
fi
rm -rf /etc/wazuh-indexer

# Validate removal
echo "Validating Wazuh Indexer removal..."

# Check for remaining files and directories
if [ "$PKG_MANAGER" == "apt-get" ]; then
    if dpkg -l | grep wazuh-indexer > /dev/null 2>&1; then
        echo "Error: Wazuh Indexer packages still present."
        exit 1
    else
        echo "Wazuh Indexer packages removed."
    fi
elif [ "$PKG_MANAGER" == "yum" ]; then
    if rpm -qa | grep wazuh-indexer > /dev/null 2>&1; then
        echo "Error: Wazuh Indexer packages still present."
        exit 1
    else
        echo "Wazuh Indexer packages removed."
    fi
fi

# Check for remaining services
if systemctl list-units --full -all | grep wazuh-indexer.service > /dev/null 2>&1; then
    echo "Error: Wazuh Indexer service still present."
    exit 1
else
    echo "Wazuh Indexer service removed."
fi

echo "Wazuh Indexer uninstallation and validation completed successfully."
