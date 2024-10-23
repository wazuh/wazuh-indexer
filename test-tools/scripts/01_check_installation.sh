#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Usage function to display help
usage() {
    echo "Usage: $0 <ARTIFACT_ID> [-v <PKG_VERSION>] [-r <PKG_REVISION>] [-n <PKG_NAME>]"
    echo
    echo "Parameters:"
    echo "    ARTIFACT_ID    The unique ID of the GHA artifact."
    echo "    -v             (Optional) The version of the wazuh-indexer package."
    echo "    -r             (Optional) The revision of the package. Defaults to '0' if not provided."
    echo "    -n             (Optional) The package name."
    echo
    echo "Please ensure you have the GITHUB_TOKEN environment variable set to access the GitHub repository."
    exit 1
}

# Check if ARTIFACT_ID is provided
if [ -z "$1" ]; then
    echo "Error: ARTIFACT_ID not provided."
    usage
fi

# Check if curl and unzip are installed
if ! command -v curl &> /dev/null || ! command -v unzip &> /dev/null; then
    echo "Error: curl and unzip must be installed."
    exit 1
fi

ARTIFACT_ID=$1
shift

while getopts v:r:n: flag
do
    case "${flag}" in
        v) PKG_VERSION=${OPTARG};;
        r) PKG_REVISION=${OPTARG};;
        n) PKG_NAME=${OPTARG};;
        *)
            usage
            ;;
    esac
done

# Validate GITHUB_TOKEN environment variable
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Environment variable GITHUB_TOKEN is not configured."
    usage
fi

# Ensure either PKG_NAME or both PKG_VERSION and PKG_REVISION are provided
if [ -z "$PKG_NAME" ] && { [ -z "$PKG_VERSION" ] || [ -z "$PKG_REVISION" ]; }; then
    echo "Error: Either a package name (-n) or both a version (-v) and revision (-r) must be provided."
    usage
fi

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

# Determine package type if PKG_NAME is not provided
ARCH=$(uname -m)
case "$OS" in
    "ubuntu" | "debian")
        PKG_FORMAT="deb"
        if [ -z "$PKG_NAME" ]; then
            [ "$ARCH" == "x86_64" ] && ARCH="amd64"
            [ "$ARCH" == "aarch64" ] && ARCH="arm64"
            PKG_NAME="wazuh-indexer_${PKG_VERSION}-${PKG_REVISION}_${ARCH}.${PKG_FORMAT}"
        fi
        ;;
    "centos" | "fedora" | "rhel" | "red hat enterprise linux")
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
