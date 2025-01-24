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
  if ! command -v "${dep}" &> /dev/null
  then
    echo "Error: Dependency '$dep' is not installed. Please install $dep and try again." >&2
    exit 1
  fi
done

# Default values
CLUSTER_IP="localhost"
USERNAME="admin"
PASSWORD="admin"

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -ip|--cluster-ip) CLUSTER_IP="$2"; shift ;;
        -u|--user) USERNAME="$2"; shift ;;
        -p|--password) PASSWORD="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

COMMANDS_INDEX="wazuh-commands"
SRC="Engine"
USR="TestUser"
TRG_ID="TestTarget"
ARG="/test/path/fake/args"
BODY="{
  \"source\": \"$SRC\",
  \"user\": \"$USR\",
  \"target\": {
    \"id\": \"$TRG_ID\",
    \"type\": \"agent\"
  },
  \"action\": {
    \"name\": \"restart\",
    \"args\": [
      \"$ARG\"
    ],
    \"version\": \"v4\"
  },
  \"timeout\": 30
}"

# Send the POST request and check it is successful
if ! curl -s -k -u "$USERNAME:$PASSWORD" -X POST "https://$CLUSTER_IP:9200/_plugins/_command_manager/commands" -H 'accept: */*' -H 'Content-Type: application/json' -d "$BODY" > /dev/null 2>&1; then
    echo "Error: Failed to create command."
    exit 1
fi
echo "Command created successfully."
# Sleep to avoid the next request to be sent before index is created
curl -s -k -u "$USERNAME:$PASSWORD" -X POST "https://$CLUSTER_IP:9200/_forcemerge" -H 'accept: */*'
sleep 2

# Fetch the indices
echo "Validating $COMMANDS_INDEX index is created..."
INDICES_RESPONSE=$(curl -s -k -u "$USERNAME:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/indices/.*?v")
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch indices."
    exit 1
fi
if echo "$INDICES_RESPONSE" | grep -q "$COMMANDS_INDEX"; then
    echo "Index created correctly."
else
    echo "Error: Index is not created."
    exit 1
fi

sleep 5
echo "Validate the command is created"
# Validate the command was created
SEARCH_RESPONSE=$(curl -s -k -u "$USERNAME:$PASSWORD" "https://$CLUSTER_IP:9200/$COMMANDS_INDEX/_search")
# Check if the request was successful
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to search for the command."
    exit 1
fi

# Check if the command is found in the search results
if echo "$SEARCH_RESPONSE" | grep -q "\"$USR\"" && echo "$SEARCH_RESPONSE" | grep -q "\"$TRG_ID\""; then
    echo "Validation successful: The command was created and found in the search results."
else
    echo "Error: The command was not found in the search results."
    exit 1
fi
