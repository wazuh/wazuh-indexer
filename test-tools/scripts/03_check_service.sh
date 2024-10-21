#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to check the status of the wazuh-indexer service
check_service_is_running() {
    systemctl is-active --quiet wazuh-indexer
    if [ $? -eq 0 ]; then
        echo "wazuh-indexer service is running."
    else
        echo "Error: wazuh-indexer service is not running." >&2
        exit 1
    fi
}

# Start wazuh-indexer service
echo "Starting wazuh-indexer service..."
systemctl daemon-reload
systemctl enable wazuh-indexer
systemctl start wazuh-indexer

# Check if the service is running
check_service_is_running

# Stop wazuh-indexer service
echo "Stopping wazuh-indexer service..."
systemctl stop wazuh-indexer

# Check if the service is stopped
systemctl is-active --quiet wazuh-indexer
if [ $? -ne 0 ]; then
    echo "wazuh-indexer service stopped successfully."
else
    echo "Error: Failed to stop wazuh-indexer service." >&2
    exit 1
fi

# Restart wazuh-indexer service
echo "Restarting wazuh-indexer service..."
systemctl restart wazuh-indexer

# Check if the service is running after restart
check_service_is_running
