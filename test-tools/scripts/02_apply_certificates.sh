#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to display usage help
usage() {
    echo
    echo "Usage: $0 <CURRENT_NODE> <SECOND_NODE> <(Optional)CURRENT_NODE_IP> <(Optional)SECOND_NODE_IP>"
    echo
    echo "Parameters:"
    echo "  CURRENT_NODE       Name of the current node"
    echo "  SECOND_NODE        Name of the second node"
    echo "  CURRENT_NODE_IP    IP address of the current node (optional, defaults to CURRENT_NODE)"
    echo "  SECOND_NODE_IP     IP address of the second node (optional, defaults to SECOND_NODE)"
    echo
    exit 1
}

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    usage
fi

# Assigning variables
CURRENT_NODE=$1
SECOND_NODE=$2
CURRENT_NODE_IP=${3:-$CURRENT_NODE}
SECOND_NODE_IP=${4:-$SECOND_NODE}
CONFIG_FILE="/etc/wazuh-indexer/opensearch.yml"
BACKUP_FILE="./opensearch.yml.bak"

# Backup the original config file
echo "Creating a backup of the original config file..."
cp $CONFIG_FILE $BACKUP_FILE

# Replace values in the config file
echo "Updating configuration..."
sed -i "s/network\.host: \"0\.0\.0\.0\"/network.host: \"${CURRENT_NODE_IP}\"/" $CONFIG_FILE
sed -i "s/node\.name: \"node-1\"/node.name: \"${CURRENT_NODE}\"/" $CONFIG_FILE
sed -i "s/#discovery\.seed_hosts:/discovery.seed_hosts:\n  - \"${CURRENT_NODE_IP}\"\n  - \"${SECOND_NODE_IP}\"/" $CONFIG_FILE
sed -i "/cluster\.initial_master_nodes:/!b;n;c- ${CURRENT_NODE}\n- ${SECOND_NODE}" $CONFIG_FILE
sed -i ':a;N;$!ba;s/plugins\.security\.nodes_dn:\n- "CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US"/plugins.security.nodes_dn:\n- "CN='"${CURRENT_NODE}"',OU=Wazuh,O=Wazuh,L=California,C=US"\n- "CN='"${SECOND_NODE}"',OU=Wazuh,O=Wazuh,L=California,C=US"/' $CONFIG_FILE

if [ $? -eq 0 ]; then
    echo "Configuration updated successfully. Backup created at ${BACKUP_FILE}"
else
    echo "Error updating configuration."
fi

# Directory for certificates
CERT_DIR="/etc/wazuh-indexer/certs"

# Extract certificates
echo "Creating certificates directory and extracting certificates..."
mkdir -p $CERT_DIR
tar -xf ./wazuh-certificates.tar -C $CERT_DIR ./$CURRENT_NODE.pem ./$CURRENT_NODE-key.pem ./admin.pem ./admin-key.pem ./root-ca.pem

if [ $? -ne 0 ]; then
    echo "Error extracting certificates."
    exit 1
fi

# Move and set permissions for certificates
echo "Moving and setting permissions for certificates..."
mv -n $CERT_DIR/$CURRENT_NODE.pem $CERT_DIR/indexer.pem
mv -n $CERT_DIR/$CURRENT_NODE-key.pem $CERT_DIR/indexer-key.pem
chmod 500 $CERT_DIR
chmod 400 $CERT_DIR/*
chown -R wazuh-indexer:wazuh-indexer $CERT_DIR

if [ $? -eq 0 ]; then
    echo "Certificates configured successfully."
else
    echo "Error configuring certificates."
fi
