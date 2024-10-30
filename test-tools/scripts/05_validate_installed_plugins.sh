#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Tool dependencies
DEPENDENCIES=(curl jq)

# Function to display usage help
usage() {
    echo "Usage: $0 [-ip <CLUSTER_IP> -u <USER> -p <PASSWORD>] -n <NODE_1> -n <NODE_2> [...]"
    echo
    echo "Parameters:"
    echo "  -ip, --cluster-ip  (Optional) IP address of the cluster (default: localhost)"
    echo "  -u, --user         (Optional) Username for authentication (default: admin)"
    echo "  -p, --password     (Optional) Password for authentication (default: admin)"
    echo "  -n, --node         Name of the nodes (add as many as needed)"
    echo
    echo "Please ensure you have all the dependencies installed: " "${DEPENDENCIES[@]}"
    exit 1
}

# Validate all dependencies are installed
for dep in "${DEPENDENCIES[@]}"
do
  if ! command -v "${dep}" &> /dev/null
  then
    echo "Error: Dependency '$dep' is not installed. Please install $dep and try again." >&2
    exit 1
  fi
done

# Default values
CLUSTER_IP="localhost"
USER="admin"
PASSWORD="admin"
NODES=()

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -ip|--cluster-ip) CLUSTER_IP="$2"; shift ;;
        -u|--user) USER="$2"; shift ;;
        -p|--password) PASSWORD="$2"; shift ;;
        -n|--node) NODES+=("$2"); shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Check if mandatory arguments are provided
if [ -z "$CLUSTER_IP" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ ${#NODES[@]} -eq 0 ]; then
    echo "Error: Missing mandatory parameter."
    usage
fi

# Check the installed plugins on each node
REQUIRED_PLUGINS=("wazuh-indexer-command-manager" "wazuh-indexer-setup")
ALL_MISSING_PLUGINS=()

echo "Checking installed plugins on Wazuh indexer nodes..."
for NODE in "${NODES[@]}"; do
    echo "Checking node $NODE..."
    RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/plugins?v" | grep "$NODE")
    # Check if the request was successful
    # shellcheck disable=SC2181
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
