#!/bin/bash

## SPDX-License-Identifier: Apache-2.0
## The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Check if the necessary arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <RUN_ID> <PKG_VERSION> <(Optional)PKG_REVISION>"
    echo
    echo "Parameters:"
    echo "    RUN_ID         The GHA workflow execution ID."
    echo "    PKG_VERSION    The version of the wazuh-indexer package."
    echo "    PKG_REVISION   (Optional) The revision of the package. Defaults to 'test' if not provided."
    echo
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    echo
    exit 1
fi

RUN_ID=$1
PKG_VERSION=$2
PKG_REVISION=${3:-"0"}
REPO="wazuh/wazuh-indexer"
URL="https://api.github.com/repos/$REPO/actions/artifacts"

# Detect OS and architecture
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$(echo $NAME | tr '[:upper:]' '[:lower:]')
else
    echo "Unsupported OS."
    exit 1
fi

ARCH=$(uname -m)
# Determine package type
case "$OS" in
    "ubuntu" | "debian")
        PKG_FORMAT="deb"
        [ "$ARCH" == "x86_64" ] && ARCH="amd64"
        PKG_NAME="wazuh-indexer_${PKG_VERSION}-${PKG_REVISION}_${ARCH}.${PKG_FORMAT}"
        ;;
    "centos" | "fedora" | "rhel" | "red hat enterprise linux")
        PKG_FORMAT="rpm"
        PKG_NAME="wazuh-indexer-${PKG_VERSION}-${PKG_REVISION}.${ARCH}.${PKG_FORMAT}"
        ;;
    *)
        echo "Unsupported OS. ${OS}"
        exit 1
        ;;
esac

# Fetch the list of artifacts
echo "Fetching artifacts list..."
RESPONSE=$(curl -s -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" $URL?name=$PKG_NAME)

# Check if the curl command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch artifacts."
    exit 1
fi

# Check if the artifact from the specified workflow run ID exists
echo "Checking ${PKG_NAME} package is generated for workflow run ${RUN_ID}"
ARTIFACT=$(echo "$RESPONSE" | jq -e ".artifacts[] | select(.workflow_run.id == $RUN_ID)")

if [ -n "$ARTIFACT" ]; then
    ARTIFACT_ID=$(echo "$ARTIFACT" | jq -r '.id')
    echo "Wazuh indexer package built successfully."
    echo "[ Artifact ID: $ARTIFACT_ID ]"
else
    echo "Error: Wazuh indexer package not found."
fi
