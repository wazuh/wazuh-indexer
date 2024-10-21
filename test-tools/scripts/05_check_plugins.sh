#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to display usage help
usage() {
    echo
    echo "Usage: $0 <CLUSTER_IP> <USER> <PASSWORD> <NODE_1> <NODE_2> [...]"
    echo
    echo "Parameters:"
    echo "  CLUSTER_IP    IP address of the cluster (default: localhost)"
    echo "  USER          Username for authentication (default: admin)"
    echo "  PASSWORD      Password for authentication (default: admin)"
    echo "  NODE_1        Name of the first node"
    echo "  NODE_2        Name of the second node (add more as needed)"
    echo
    exit 1
}

# Check if curl and jq are installed
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq must be installed."
    exit 1
fi

# Check if at least four arguments are provided
if [ "$#" -lt 4 ]; then
    usage
fi

# Assigning variables
CLUSTER_IP=${1:-"localhost"}
USER=${2:-"admin"}
PASSWORD=${3:-"admin"}
NODES=${@:4}  # List of nodes passed as arguments starting from the 4th

# Check the installed plugins on each node
REQUIRED_PLUGINS=("wazuh-indexer-command-manager" "wazuh-indexer-setup")
ALL_MISSING_PLUGINS=()

echo "Checking installed plugins on Wazuh indexer nodes..."

for NODE in $NODES; do
    echo "Checking node $NODE..."
    RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200/_cat/plugins?v | grep $NODE)

    # Check if the request was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to Wazuh indexer."
        exit 1
    fi

    MISSING_PLUGINS=()
    for PLUGIN in "${REQUIRED_PLUGINS[@]}"; do
        if echo "$RESPONSE" | grep -q "$PLUGIN"; then
            echo "  $PLUGIN is installed on $NODE."
        else
            MISSING_PLUGINS+=("$PLUGIN")
        fi
    done

    if [ ${#MISSING_PLUGINS[@]} -ne 0 ]; then
        echo "Error: The following required plugins are missing on $NODE:"
        for PLUGIN in "${MISSING_PLUGINS[@]}"; do
            echo "  $PLUGIN"
        done
        ALL_MISSING_PLUGINS+=("${MISSING_PLUGINS[@]}")
    fi
done

if [ ${#ALL_MISSING_PLUGINS[@]} -ne 0 ]; then
    echo "Error: Some nodes are missing required plugins."
    exit 1
fi

echo "All required plugins are installed on all nodes."
