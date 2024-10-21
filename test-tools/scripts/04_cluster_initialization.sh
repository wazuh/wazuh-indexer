#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to display usage help
usage() {
    echo
    echo "Usage: $0 <CLUSTER_IP> <USER> <PASSWORD>"
    echo
    echo "Parameters:"
    echo "  CLUSTER_IP    IP address of the cluster (default: localhost)"
    echo "  USER          Username for authentication (default: admin)"
    echo "  PASSWORD      Password for authentication (default: admin)"
    echo
    exit 1
}

# Check if curl and jq are installed
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq must be installed."
    exit 1
fi

# Assigning variables
CLUSTER_IP=${1:-"localhost"}
USER=${2:-"admin"}
PASSWORD=${3:-"admin"}

# Initialize cluster
echo "Initializing wazuh-indexer cluster..."
bash /usr/share/wazuh-indexer/bin/indexer-security-init.sh &> /dev/null

# Check if the initialization was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to initialize cluster."
    exit 1
fi

# Check the Wazuh indexer status
echo "Checking cluster status..."
RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200)

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to cluster."
    exit 1
fi

# Parse and print the response
INDEXER_NAME=$(echo $RESPONSE | jq -r '.name')
CLUSTER_NAME=$(echo $RESPONSE | jq -r '.cluster_name')
VERSION_NUMBER=$(echo $RESPONSE | jq -r '.version.number')

echo "Indexer Status:"
echo "  Node Name: $INDEXER_NAME"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Version Number: $VERSION_NUMBER"

# Verify the Wazuh indexer nodes
echo "Verifying the Wazuh indexer nodes..."
NODES_RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200/_cat/nodes?v)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve Wazuh indexer nodes."
    exit 1
fi

echo "Nodes:"
echo "$NODES_RESPONSE"

echo "Initialization completed successfully."
