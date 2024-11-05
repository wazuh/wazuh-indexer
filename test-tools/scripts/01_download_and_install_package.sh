#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Tool dependencies
DEPENDENCIES=(curl jq unzip)
# Default package revision
PKG_REVISION="0"
# Wazuh indexer repository
REPO="wazuh/wazuh-indexer"

# Function to display usage help
usage() {
    echo "Usage: $0 --run-id <RUN_ID> [-v <PKG_VERSION>] [-r <PKG_REVISION>] [-n <PKG_NAME>]"
    echo
    echo "Parameters:"
    echo "    -id, --run-id         The GHA workflow execution ID."
    echo "    -v, --version         (Optional) The version of the wazuh-indexer package."
    echo "    -r, --revision        (Optional) The revision of the package. Defaults to '0' if not provided."
    echo "    -n, --name            (Optional) The package name. If not provided, it will be configured based on version and revision."
    echo
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository, and all the dependencies installed: " "${DEPENDENCIES[@]}"
    exit 1
}

# Parse named parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --artifact-id|-id) RUN_ID="$2"; shift ;;
        --version|-v) PKG_VERSION="$2"; shift ;;
        --revision|-r) PKG_REVISION="$2"; shift ;;
        --name|-n) PKG_NAME="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate all dependencies are installed
for dep in "${DEPENDENCIES[@]}"
do
  if ! command -v "${dep}" &> /dev/null
  then
    echo "Error: Dependency '$dep' is not installed. Please install $dep and try again." >&2
    exit 1
  fi
done

# Check if RUN_ID is provided
if [ -z "$RUN_ID" ]; then
    echo "Error: RUN_ID is required."
    usage
fi

# Validate GITHUB_TOKEN environment variable
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    exit 1
fi

# Ensure either PKG_NAME or both PKG_VERSION and PKG_REVISION are provided
if [ -z "$PKG_NAME" ] && { [ -z "$PKG_VERSION" ] || [ -z "$PKG_REVISION" ]; }; then
    echo "Error: Either a package name (--name) or both a version (--version) and revision (--revision) must be provided."
    usage
fi

# Detect OS and architecture
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
else
    echo "Unsupported OS."
    exit 1
fi

# Determine package type if PKG_NAME is not provided
ARCH=$(uname -m)
case "$OS" in
    *ubuntu* | *debian*)
        PKG_FORMAT="deb"
        if [ -z "$PKG_NAME" ]; then
            [ "$ARCH" == "x86_64" ] && ARCH="amd64"
            [ "$ARCH" == "aarch64" ] && ARCH="arm64"
            PKG_NAME="wazuh-indexer_${PKG_VERSION}-${PKG_REVISION}_${ARCH}.${PKG_FORMAT}"
        fi
        ;;
    *centos* | *fedora* | *rhel* | *"red hat"* | *alma*)
        PKG_FORMAT="rpm"
        if [ -z "$PKG_NAME" ]; then
            PKG_NAME="wazuh-indexer-${PKG_VERSION}-${PKG_REVISION}.${ARCH}.${PKG_FORMAT}"
        fi
        ;;
    *)
        echo "Unsupported OS."
        exit 1
        ;;
esac

# Check if the package is already present
if [ -f "$PKG_NAME" ]; then
    echo "Package $PKG_NAME found locally. Reusing existing package."
else
    # Fetch the list of artifacts
    echo "Fetching artifacts list..."
    RUN_URL="https://api.github.com/repos/${REPO}/actions/artifacts"
    RESPONSE=$(curl -s -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "$RUN_URL?name=$PKG_NAME")

    # Check if the curl command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch artifacts."
        exit 1
    fi

    # Check if the artifact from the specified workflow run ID exists
    echo "Checking ${PKG_NAME} package is generated for workflow run ${RUN_ID}"
    ARTIFACT=$(echo "$RESPONSE" | jq -e ".artifacts[] | select(.workflow_run.id == $RUN_ID)")

    if [ -z "$ARTIFACT" ]; then
        echo "Error: Wazuh indexer package not found."
        exit 1
    fi

    ARTIFACT_ID=$(echo "$ARTIFACT" | jq -r '.id')
    echo "Wazuh indexer artifact detected. Artifact ID: $ARTIFACT_ID"

    # Download the package
    ARTIFACT_URL="https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip"
    echo "Downloading wazuh-indexer package from GitHub artifactory..."
    echo "(It could take a couple of minutes)"

    if ! curl -L -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$ARTIFACT_URL" -o package.zip > /dev/null 2>&1; then
        echo "Error downloading package."
        exit 1
    fi
    echo "Package downloaded successfully"

    # Unzip the package
    echo "Decompressing wazuh-indexer package..."
    unzip ./package.zip
    rm package.zip

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "Error unzipping package."
        exit 1
    fi
    echo "Package decompressed"
fi

# Install the package
echo "Installing wazuh-indexer package..."
case "$PKG_FORMAT" in
    "deb")
        sudo dpkg -i "$PKG_NAME" > /dev/null 2>&1
        ;;
    "rpm")
        sudo rpm -i "$PKG_NAME" > /dev/null 2>&1
        ;;
esac

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error installing package."
    exit 1
fi

echo "Package installed successfully."
