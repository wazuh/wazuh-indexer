#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Tool dependencies
DEPENDENCIES=(curl jq)

# Function to display usage help
usage() {
    echo "Usage: $0 [-ip <CLUSTER_IP>] [-u <USER>] [-p <PASSWORD>]"
    echo
    echo "Parameters:"
    echo "  -ip, --cluster-ip  (Optional) IP address of the cluster. Default: localhost"
    echo "  -u, --user         (Optional) Username for authentication. Default: admin"
    echo "  -p, --password     (Optional) Password for authentication. Default: admin"
    echo
    echo "Please ensure you have all the dependencies installed: " "${DEPENDENCIES[@]}"
    exit 1
}

# Validate all dependencies are installed
for dep in "${DEPENDENCIES[@]}"
do
  if ! command -v  "${dep}" &> /dev/null
  then
    echo "Error: Dependency '$dep' is not installed. Please install $dep and try again." >&2
    exit 1
  fi
done

# Default values
CLUSTER_IP="localhost"
USER="admin"
PASSWORD="admin"

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -ip|--cluster-ip) CLUSTER_IP="$2"; shift ;;
        -u|--user) USER="$2"; shift ;;
        -p|--password) PASSWORD="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Initialize cluster
echo "Initializing wazuh-indexer cluster..."
bash /usr/share/wazuh-indexer/bin/indexer-security-init.sh > /dev/null 2>&1

# Check if the initialization was successful
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to initialize cluster."
    exit 1
fi

# Check the Wazuh indexer status
echo "Checking cluster status..."
sleep 2
RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200")

# Check if the request was successful
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to cluster."
    exit 1
fi

# Parse and print the response
INDEXER_NAME=$(echo "$RESPONSE" | jq -r '.name')
CLUSTER_NAME=$(echo "$RESPONSE" | jq -r '.cluster_name')
VERSION_NUMBER=$(echo "$RESPONSE" | jq -r '.version.number')
echo "Indexer Status:"
echo "  Node Name: $INDEXER_NAME"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Version Number: $VERSION_NUMBER"

# Verify the Wazuh indexer nodes
echo "Verifying the Wazuh indexer nodes..."
NODES_RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/nodes?v")

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve Wazuh indexer nodes."
    exit 1
fi

echo "Nodes:"
echo "$NODES_RESPONSE"
echo "Initialization completed successfully."
