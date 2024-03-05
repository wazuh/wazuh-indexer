#!/bin/bash

# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

set -ex


# ====
# Usage
# ====
function usage() {
    echo "Usage: $0 [args]"
    echo ""
    echo "Arguments:"
    echo -e "-v VERSION\t[Required] Wazuh Indexer version."
    echo -e "-p PLATFORM\t[Optional] Platform, default is 'uname -s'."
    echo -e "-a ARCHITECTURE\t[Optional] Build architecture, default is 'uname -m'."
    echo -e "-d DISTRIBUTION\t[Optional] Distribution, default is 'tar'."
    echo -e "-o OUTPUT\t[Optional] Output path, default is 'artifacts'."
    echo -e "-h help"
}

# ====
# Parse arguments
# ====
function parse_args() {

    while getopts ":h:v:o:p:a:d:" arg; do
        case $arg in
        h)
            usage
            exit 1
            ;;
        v)
            VERSION=$OPTARG
            ;;
        o)
            OUTPUT=$OPTARG
            ;;
        p)
            PLATFORM=$OPTARG
            ;;
        a)
            ARCHITECTURE=$OPTARG
            ;;
        d)
            DISTRIBUTION=$OPTARG
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        ?)
            echo "Invalid option: -${arg}"
            exit 1
            ;;
        esac
    done

    if [ -z "$VERSION" ]; then
        echo "Error: You must specify the OpenSearch version"
        usage
        exit 1
    fi

    [ -z "$OUTPUT" ] && OUTPUT=artifacts

    # Assemble distribution artifact
    # see https://github.com/opensearch-project/OpenSearch/blob/main/settings.gradle#L34 for other distribution targets

    [ -z "$PLATFORM" ] && PLATFORM=$(uname -s | awk '{print tolower($0)}')
    [ -z "$ARCHITECTURE" ] && ARCHITECTURE=$(uname -m)
    [ -z "$DISTRIBUTION" ] && DISTRIBUTION="tar"

    case $PLATFORM-$DISTRIBUTION-$ARCHITECTURE in
    linux-tar-x64 | darwin-tar-x64)
        PACKAGE="tar"
        EXT="tar.gz"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    linux-tar-arm64 | darwin-tar-arm64)
        PACKAGE="tar"
        EXT="tar.gz"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
        ;;
    linux-deb-x64)
        PACKAGE="deb"
        EXT="deb"
        TARGET="deb"
        SUFFIX="amd64"
        ;;
    linux-deb-arm64)
        PACKAGE="deb"
        EXT="deb"
        TARGET="arm64-deb"
        SUFFIX="arm64"
        ;;
    linux-rpm-x64)
        PACKAGE="rpm"
        EXT="rpm"
        TARGET="rpm"
        SUFFIX="x86_64"
        ;;
    linux-rpm-arm64)
        PACKAGE="rpm"
        EXT="rpm"
        TARGET="arm64-rpm"
        SUFFIX="aarch64"
        ;;
    *)
        echo "Unsupported platform-distribution-architecture combination: $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
        exit 1
        ;;
    esac
}


# ====
# RPM test
# ====
# function test_rpm() {
    # No image available using RPM 
    # https://github.com/actions/runner-images#available-images
# }

# ====
# DEB test
# ====
function test_deb() {
    # Install
    DEBIAN_FRONTEND=noninteractive dpkg -i "${OUTPUT}/dist/${ARTIFACT_NAME}"; 
    systemctl daemon-reload;
    systemctl enable wazuh-indexer.service;
    systemctl start wazuh-indexer;
    systemctl status wazuh-indexer --no-pager | grep "active (running)"
}

# ====
# Main function
# ====
function main() {
    parse_args "${@}"

    echo "Testing wazuh-indexer for $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"

    ARTIFACT_NAME=$(ls "${OUTPUT}/dist/" | grep "wazuh-indexer-$VERSION\_$SUFFIX.*\.$EXT")

    case $PACKAGE in
    tar)
        # assemble_tar
        ;;
    rpm)
        # assemble_rpm
        ;;
    deb)
        test_deb
        ;;
    esac
}

main "${@}"
