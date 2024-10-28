#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Tool dependencies
DEPENDENCIES=(curl jq unzip)
# Default package revision
PKG_REVISION="0"

# Function to display usage help
usage() {
    echo "Usage: $0 --artifact-id <ARTIFACT_ID> [-v <PKG_VERSION>] [-r <PKG_REVISION>] [-n <PKG_NAME>]"
    echo
    echo "Parameters:"
    echo "    -id, --artifact-id    The GHA workflow execution ID."
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
        --artifact-id|-id) ARTIFACT_ID="$2"; shift ;;
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

# Check if ARTIFACT_ID is provided
if [ -z "$ARTIFACT_ID" ]; then
    echo "Error: ARTIFACT_ID is required."
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

REPO="wazuh/wazuh-indexer"
URL="https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip"

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

# Download the package
echo "Downloading wazuh-indexer package from GitHub artifactory..."
echo "(It could take a couple of minutes)"

if ! curl -L -H "Accept: application/vnd.github+json" \
         -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "X-GitHub-Api-Version: 2022-11-28" \
         "$URL" -o package.zip > /dev/null 2>&1; then
    echo "Error downloading package."
    exit 1
fi
echo "Package downloaded successfully"

# Unzip the package
echo "Decompressing wazuh-indexer package..."
unzip ./package.zip
rm package.zip

if [ $? -ne 0 ]; then
    echo "Error unzipping package."
    exit 1
fi
echo "Package decompressed"

# Install the package
echo "Installing wazuh-indexer package..."
case "$PKG_FORMAT" in
    "deb")
        sudo dpkg -i "$PKG_NAME"
        ;;
    "rpm")
        sudo rpm -i "$PKG_NAME"
        ;;
esac

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "Error installing package."
    exit 1
fi

echo "Package installed successfully."
