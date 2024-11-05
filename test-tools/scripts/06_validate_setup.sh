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

# List of expected items
EXPECTED_TEMPLATES=("index-template-agent" "index-template-alerts" "index-template-fim" "index-template-packages"
    "index-template-processes" "index-template-system" "index-template-vulnerabilities")

# Fetch the templates
echo "Fetching templates from Wazuh indexer cluster..."
TEMPLATES_RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/templates?v")
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
        # Fetch the template info to check for required fields
        TEMPLATE_INFO=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_template/$TEMPLATE")
        if ! echo "$TEMPLATE_INFO" | jq -e '.[] | .mappings.properties.agent.properties.id' > /dev/null; then
            echo "  Error: Template $TEMPLATE is missing required field 'agent.id'."
            MISSING_TEMPLATES+=("$TEMPLATE")
        elif ! echo "$TEMPLATE_INFO" | jq -e '.[] | .mappings.properties.agent.properties.groups' > /dev/null; then
            echo "  Error: Template $TEMPLATE is missing required field 'agent.groups'."
            MISSING_TEMPLATES+=("$TEMPLATE")
        else
            echo "  Template $TEMPLATE is created correctly."
        fi
    else
        MISSING_TEMPLATES+=("$TEMPLATE")
        echo "  Error: Template $TEMPLATE is missing."
    fi
done

if [ ${#MISSING_TEMPLATES[@]} -ne 0 ]; then
    echo "Some templates were not created correctly:"
    for TEMPLATE in "${MISSING_TEMPLATES[@]}"; do
        echo "  $TEMPLATE"
    done
    echo
else
    echo "All templates are correctly created."
    echo
fi

# Fetch the indices
echo "Fetching indices from Wazuh indexer cluster..."
INDICES_RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/indices?v")
# Check if the request was successful
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch indices."
    exit 1
fi

# Fetch the protected indices
echo "Fetching protected indices from Wazuh indexer cluster..."
PROTECTED_RESPONSE=$(curl -s -k -u "$USER:$PASSWORD" "https://$CLUSTER_IP:9200/_cat/indices/.*?v")
# Check if the request was successful
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch indices."
    exit 1
fi

# Validate index patterns
echo "Validating index patterns..."
INVALID_PATTERNS=()
while read -r line; do
    TEMPLATE_NAME=$(echo "$line" | awk '{print $1}')
    INDEX_PATTERN=$(echo "$line" | awk '{print $2}' | tr -d '[]')

    if [[ $INDEX_PATTERN == .* ]]; then
        TO_MATCH=$PROTECTED_RESPONSE
    else
        TO_MATCH=$INDICES_RESPONSE
    fi

    # Check if index pattern ends with '*'
    if [[ $INDEX_PATTERN != *\* ]]; then
        echo "  Error: Index pattern $INDEX_PATTERN does not end with '*'."
        INVALID_PATTERNS+=("$INDEX_PATTERN")
        continue
    fi

    if echo "$TO_MATCH" | grep -q "$INDEX_PATTERN"; then
        echo "  Index pattern $INDEX_PATTERN is valid."
    else
        INVALID_PATTERNS+=("$INDEX_PATTERN")
        echo "  Error: Index pattern $INDEX_PATTERN not found in indices for template $TEMPLATE_NAME."
    fi
done <<< "$(echo "$TEMPLATES_RESPONSE" | tail -n +2)"  # Skip header line

if [ ${#INVALID_PATTERNS[@]} -ne 0 ]; then
    echo "Errors on index-patterns detected:"
    for PATTERN in "${INVALID_PATTERNS[@]}"; do
        echo "  $PATTERN"
    done
    echo
else
    echo "Index-patterns validated successfully."
fi
