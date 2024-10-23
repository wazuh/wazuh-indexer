#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Usage function to display help
usage() {
    echo "Usage: $0 <ARTIFACT_ID> <PKG_VERSION> <(Optional)PKG_REVISION>"
    echo
    echo "Parameters:"
    echo "    ARTIFACT_ID    The unique ID of the GHA artifact."
    echo "    PKG_VERSION    The version of the wazuh-indexer package."
    echo "    PKG_REVISION   (Optional) The revision of the package. Defaults to 'test' if not provided."
    echo
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    echo
    exit 1
}

# Check if GITHUB_TOKEN env var is set
if [ -z "$1" ]; then
    echo "Error: Environment variable GITHUB_TOKEN is not configured."
    usage
fi

# Check if ARTIFACT_ID is provided
if [ -z "$1" ]; then
    echo "Error: ARTIFACT_ID not provided."
    usage
fi

# Check if PKG_VERSION is provided
if [ -z "$2" ]; then
    echo "Error: PKG_VERSION not provided."
    usage
fi

ARTIFACT_ID=$1
PKG_VERSION=$2
PKG_REVISION=${3:-"0"}
REPO="wazuh/wazuh-indexer"
URL="https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip"

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
        [ "$ARCH" == "aarch64" ] && ARCH="arm64"
        # Construct package name
        PKG_NAME="wazuh-indexer_${PKG_VERSION}-${PKG_REVISION}_${ARCH}.${PKG_FORMAT}"
        ;;
    "centos" | "fedora" | "rhel" | "red hat enterprise linux")
        PKG_FORMAT="rpm"
        # Construct package name
        PKG_NAME="wazuh-indexer-${PKG_VERSION}-${PKG_REVISION}.${ARCH}.${PKG_FORMAT}"
        ;;
    *)
        echo "Unsupported OS."
        exit 1
        ;;
esac

# Download the package
echo "Downloading wazuh-indexer package from GitHub artifactory..."
echo "(It could take a couple minutes)"
curl -L -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    $URL -o package.zip > /dev/null 2>&1
if [ $? -ne 0 ]; then
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
        sudo dpkg -i $PKG_NAME
        ;;
    "rpm")
        sudo rpm -i $PKG_NAME
        ;;
esac
if [ $? -ne 0 ]; then
    echo "Error installing package."
    exit 1
fi

echo "Package installed successfully."
