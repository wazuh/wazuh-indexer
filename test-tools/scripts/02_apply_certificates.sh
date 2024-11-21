#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Tool dependencies
DEPENDENCIES=(tar)

# Function to display usage help
usage() {
    echo "Usage: $0 --path-to-certs <PATH_TO_CERTS> --current-node <CURRENT_NODE> [--second-node <SECOND_NODE>] [--current-node-ip <CURRENT_NODE_IP>] [--second-node-ip <SECOND_NODE_IP>]"
    echo
    echo "Parameters:"
    echo "    -p, --path-to-certs     Path to the generated Wazuh certificates tar"
    echo "    -n, --current-node      Name of the current node"
    echo "    -s, --second-node       (Optional) Name of the second node"
    echo "    -nip, --current-node-ip (Optional) IP address of the current node. Default: CURRENT_NODE"
    echo "    -sip, --second-node-ip  (Optional) IP address of the second node. Default: SECOND_NODE"
    echo
    echo "Please ensure you have all the dependencies installed: " "${DEPENDENCIES[@]}"
    exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --path-to-certs|-p) PATH_TO_CERTS="$2"; shift ;;
        --current-node|-n) CURRENT_NODE="$2"; shift ;;
        --second-node|-s) SECOND_NODE="$2"; shift ;;
        --current-node-ip|-nip) CURRENT_NODE_IP="$2"; shift ;;
        --second-node-ip|-sip) SECOND_NODE_IP="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate all dependencies are installed
for dep in "${DEPENDENCIES[@]}"
do
  if ! command -v  ${dep} &> /dev/null
  then
    echo "Error: Dependency '$dep' is not installed. Please install $dep and try again." >&2
    exit 1
  fi
done

# Validate mandatory arguments
if [ -z "$PATH_TO_CERTS" ] || [ -z "$CURRENT_NODE" ]; then
    echo "Error: Missing mandatory parameter."
    usage
fi

# Set default values if optional arguments are not provided
CURRENT_NODE_IP=${CURRENT_NODE_IP:-$CURRENT_NODE}
SECOND_NODE_IP=${SECOND_NODE_IP:-$SECOND_NODE}
CONFIG_FILE="/etc/wazuh-indexer/opensearch.yml"
BACKUP_FILE="./opensearch.yml.bak"

# Backup the original config file
echo "Creating a backup of the original config file..."
cp $CONFIG_FILE $BACKUP_FILE

# Replace values in the config file
echo "Updating configuration..."
sed -i "s/node\.name: \"node-1\"/node.name: \"${CURRENT_NODE}\"/" $CONFIG_FILE

if [ -n "$SECOND_NODE" ]; then
    sed -i "s/#discovery\.seed_hosts:/discovery.seed_hosts:\n  - \"${CURRENT_NODE_IP}\"\n  - \"${SECOND_NODE_IP}\"/" $CONFIG_FILE
    sed -i "/cluster\.initial_master_nodes:/!b;n;c- ${CURRENT_NODE}\n- ${SECOND_NODE}" $CONFIG_FILE
    sed -i ':a;N;$!ba;s/plugins\.security\.nodes_dn:\n- "CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US"/plugins.security.nodes_dn:\n- "CN='"${CURRENT_NODE}"',OU=Wazuh,O=Wazuh,L=California,C=US"\n- "CN='"${SECOND_NODE}"',OU=Wazuh,O=Wazuh,L=California,C=US"/' $CONFIG_FILE
else
    sed -i "s/#discovery\.seed_hosts:/discovery.seed_hosts:\n  - \"${CURRENT_NODE_IP}\"/" $CONFIG_FILE
    sed -i "/cluster\.initial_master_nodes:/!b;n;c- ${CURRENT_NODE}" $CONFIG_FILE
    sed -i ':a;N;$!ba;s/plugins\.security\.nodes_dn:\n- "CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US"/plugins.security.nodes_dn:\n- "CN='"${CURRENT_NODE}"',OU=Wazuh,O=Wazuh,L=California,C=US"/' $CONFIG_FILE
fi

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "Configuration updated successfully. Backup created at ${BACKUP_FILE}"
else
    echo "Error updating configuration."
    exit 1
fi

# Directory for certificates
CERT_DIR="/etc/wazuh-indexer/certs"
if [ -d "$CERT_DIR" ]; then
    echo "Certificates directory already exists. Removing it..."
    rm -rf
fi
# Extract certificates
echo "Creating certificates directory and extracting certificates..."
mkdir -p $CERT_DIR

if ! tar -xf "$PATH_TO_CERTS" -C "$CERT_DIR" "./$CURRENT_NODE.pem" "./$CURRENT_NODE-key.pem" "./admin.pem" "./admin-key.pem" "./root-ca.pem" ; then
    echo "Error extracting certificates."
    exit 1
fi

# Move and set permissions for certificates
echo "Moving and setting permissions for certificates..."
mv -n "$CERT_DIR/$CURRENT_NODE.pem" "$CERT_DIR/indexer.pem"
mv -n "$CERT_DIR/$CURRENT_NODE-key.pem" "$CERT_DIR/indexer-key.pem"
chmod 500 "$CERT_DIR"
chmod 400 "$CERT_DIR"/*
chown -R wazuh-indexer:wazuh-indexer "$CERT_DIR"

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "Certificates configured successfully."
else
    echo "Error configuring certificates."
    exit 1
fi
