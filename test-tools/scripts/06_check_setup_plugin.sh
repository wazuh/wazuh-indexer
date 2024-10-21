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
    echo "  CLUSTER_IP    (Optional) IP address of the cluster (default: localhost)"
    echo "  USER          (Optional) Username for authentication (default: admin)"
    echo "  PASSWORD      (Optional) Password for authentication (default: admin)"
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

# List of expected items
EXPECTED_TEMPLATES=("vulnerabilities" "fim" "inventory-system" "inventory-packages" "inventory-processes" "alerts" "agent")

# Fetch the templates
echo "Fetching templates from Wazuh indexer cluster..."
TEMPLATES_RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200/_cat/templates?v)
# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch templates."
    exit 1
fi

# Validate the templates
MISSING_TEMPLATES=()
echo "Validating templates..."
for TEMPLATE in "${EXPECTED_TEMPLATES[@]}"; do
    if echo "$TEMPLATES_RESPONSE" | grep -q "$TEMPLATE"; then
        echo "  Template $TEMPLATE is created."
    else
        MISSING_TEMPLATES+=("$TEMPLATE")
        echo "  Error: Template $TEMPLATE is missing."
    fi
done

if [ ${#MISSING_TEMPLATES[@]} -ne 0 ]; then
    echo "Some templates are missing:"
    for TEMPLATE in "${MISSING_TEMPLATES[@]}"; do
        echo "  $TEMPLATE"
    done
    exit 1
fi

echo "All templates are correctly created."
echo

# Fetch the indices
echo "Fetching indices from Wazuh indexer cluster..."
INDICES_RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200/_cat/indices?v)
# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch indices."
    exit 1
fi

# Fetch the protected indices
echo "Fetching protected indices from Wazuh indexer cluster..."
PROTECTED_RESPONSE=$(curl -s -k -u $USER:$PASSWORD https://$CLUSTER_IP:9200/_cat/indices/.*?v)
# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch indices."
    exit 1
fi

# Validate index patterns
echo "Validating index patterns..."
INVALID_PATTERNS=()
while read -r line; do
    TEMPLATE_NAME=$(echo $line | awk '{print $1}')
    INDEX_PATTERN=$(echo $line | awk '{print $2}' | tr -d '[]')

    if [[ $INDEX_PATTERN == .* ]]; then
        TO_MATCH=$PROTECTED_RESPONSE
    else
        TO_MATCH=$INDICES_RESPONSE
    fi

    if echo "$TO_MATCH" | grep -q "$INDEX_PATTERN"; then
        echo "  Index pattern $INDEX_PATTERN is valid for template $TEMPLATE_NAME."
    else
        INVALID_PATTERNS+=("$INDEX_PATTERN")
        echo "  Error: Index pattern $INDEX_PATTERN not found in indices for template $TEMPLATE_NAME."
    fi
    # Check if index pattern ends with '*'
    if [[ $INDEX_PATTERN != *\* ]]; then
        echo "  Warning: Index pattern $INDEX_PATTERN does not end with '*'."
        INVALID_PATTERNS+=("$INDEX_PATTERN")
    fi
done <<< "$(echo "$TEMPLATES_RESPONSE" | tail -n +2)"  # Skip header line

if [ ${#INVALID_PATTERNS[@]} -ne 0 ]; then
    echo "Some index patterns were not found in the indices."
    exit 1
fi

echo "All index patterns are valid."
