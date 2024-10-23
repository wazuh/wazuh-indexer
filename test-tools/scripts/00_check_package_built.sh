#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Default package revision
PKG_REVISION="0"

# Check if the necessary arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <RUN_ID> [-v <PKG_VERSION>] [-r <PKG_REVISION>] [-n <PKG_NAME>]"
    echo
    echo "Parameters:"
    echo "    RUN_ID         The GHA workflow execution ID."
    echo "    -v             (Optional) The version of the wazuh-indexer package."
    echo "    -r             (Optional) The revision of the package. Defaults to '0' if not provided."
    echo "    -n             (Optional) The package name. If not provided, it will be configured based on version and revision."
    echo
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    exit 1
fi

RUN_ID=$1
shift

while getopts v:r:n: flag
do
    case "${flag}" in
        v) PKG_VERSION=${OPTARG};;
        r) PKG_REVISION=${OPTARG};;
        n) PKG_NAME=${OPTARG};;
        *)
            echo "Usage: $0 <RUN_ID> [-v <PKG_VERSION>] [-r <PKG_REVISION>] [-n <PKG_NAME>]"
            exit 1
            ;;
    esac
done

# Validate GITHUB_TOKEN environment variable
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    exit 1
fi

# Ensure either PKG_NAME or both PKG_VERSION and PKG_REVISION are provided
if [ -z "$PKG_NAME" ] && { [ -z "$PKG_VERSION" ] || [ -z "$PKG_REVISION" ]; }; then
    echo "Error: Either a package name (-n) or both a version (-v) and revision (-r) must be provided."
    exit 1
fi

REPO="wazuh/wazuh-indexer"
URL="https://api.github.com/repos/$REPO/actions/artifacts"

# Determine package type if PKG_NAME is not provided
if [ -z "$PKG_NAME" ]; then
    ARCH=$(uname -m)
    case "$(uname -n)" in
        "ubuntu" | "debian")
            PKG_FORMAT="deb"
            [ "$ARCH" == "x86_64" ] && ARCH="amd64"
            [ "$ARCH" == "aarch64" ] && ARCH="arm64"
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
fi

# Fetch the list of artifacts
echo "Fetching artifacts list..."
RESPONSE=$(curl -s -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "$URL?name=$PKG_NAME")

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
