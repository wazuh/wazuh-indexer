#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Assigning variables
CLUSTER_IP=${1:-"localhost"}
USERNAME=${2:-"admin"}
PASSWORD=${3:-"admin"}

# Check for curl command
if ! command -v curl &> /dev/null
then
    echo "curl command could not be found"
    exit
fi

COMMANDS_INDEX=".commands"
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

# Send the POST request
RESPONSE=$(curl -s -k -u $USERNAME:$PASSWORD -X POST https://$CLUSTER_IP:9200/_plugins/_command_manager/commands -H 'accept: */*' -H 'Content-Type: application/json' -d "$BODY")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create command."
    exit 1
fi
echo "Command created successfully."

# Fetch the indices
echo "Validating .commands index is created..."
INDICES_RESPONSE=$(curl -s -k -u $USERNAME:$PASSWORD https://$CLUSTER_IP:9200/_cat/indices/.*?v)
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

echo "Validate the command is created"
# Validate the command was created
SEARCH_RESPONSE=$(curl -s -k -u $USERNAME:$PASSWORD https://$CLUSTER_IP:9200/.commands/_search)
# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to search for the command."
    exit 1
fi

# Extract and validate specific fields
COMMAND_FOUND=$(echo "$SEARCH_RESPONSE" | jq -r '.hits.hits[] | select(._source.command.source == "Engine" and ._source.command.user == "TestUser" and ._source.command.target.id == "TestTarget" and ._source.command.action.args[0] == "/test/path/fake/args")')

if [ -n "$COMMAND_FOUND" ]; then
    echo "Validation successful: The command was created and found in the search results."
else
    echo "Error: The command was not found in the search results."
    exit 1
fi
