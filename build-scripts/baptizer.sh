#!/bin/bash

set -e

function usage() {
    echo "Usage: $0 [args]"
    echo ""
    echo "Arguments:"
    echo -e "-p PLATFORM\t[Optional] Platform, default is 'uname -s'."
    echo -e "-a ARCHITECTURE\t[Optional] Build architecture, default is 'uname -m'."
    echo -e "-d DISTRIBUTION\t[Optional] Distribution, default is 'tar'."
    echo -e "-r REVISION\t[Optional] Package revision, default is '0'."
    echo -e "-l PLUGINS_HASH\t[Optional] Commit hash from the wazuh-indexer-plugins repository"
    echo -e "-e REPORTING_HASH\t[Optional] Commit hash from the wazuh-indexer-reporting repository"
    echo -e "-m MIN\t[Optional] Use naming convention for minimal packages, default is 'false'."
    echo -e "-x RELEASE\t[Optional] Use release naming convention, default is 'false'."
    echo -e "-h help"
}

# ====
# Parse arguments
# ====
function parse_args() {

    while getopts ":hp:a:d:r:l:e:mx" arg; do
        case $arg in
        h)
            usage
            exit 1
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
        r)
            REVISION=$OPTARG
            ;;
        l)
            PLUGINS_HASH=$OPTARG
            ;;
         e)

            REPORTING_HASH=$OPTARG

            ;;
        m)
            IS_MIN=true
            ;;
        x)
            IS_RELEASE=true
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

    [ -z "$PLATFORM" ] && PLATFORM=$(uname -s | awk '{print tolower($0)}')
    [ -z "$ARCHITECTURE" ] && ARCHITECTURE=$(uname -m)
    [ -z "$DISTRIBUTION" ] && DISTRIBUTION="tar"
    [ -z "$REVISION" ] && REVISION="0"
    [ -z "$IS_MIN" ] && IS_MIN=false
    [ -z "$IS_RELEASE" ] && IS_RELEASE=false

    case $PLATFORM-$DISTRIBUTION-$ARCHITECTURE in
    linux-tar-x64 | darwin-tar-x64)
        EXT="tar.gz"
        SUFFIX="$PLATFORM-x64"
        ;;
    linux-tar-arm64 | darwin-tar-arm64)
        EXT="tar.gz"
        SUFFIX="$PLATFORM-arm64"
        ;;
    linux-deb-x64)
        EXT="deb"
        SUFFIX="amd64"
        ;;
    linux-deb-arm64)
        EXT="deb"
        SUFFIX="arm64"
        ;;
    linux-rpm-x64)
        EXT="rpm"
        SUFFIX="x86_64"
        ;;
    linux-rpm-arm64)
        EXT="rpm"
        SUFFIX="aarch64"
        ;;
    windows-zip-x64)
        EXT="zip"
        SUFFIX="$PLATFORM-x64"
        ;;
    windows-zip-arm64)
        EXT="zip"
        SUFFIX="$PLATFORM-arm64"
        ;;
    *)
        echo "Unsupported platform-distribution-architecture combination: $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
        exit 1
        ;;
    esac

}

# ====
# Naming convention for release packages
# ====
function get_release_name() {
    if [ "$EXT" = "rpm" ]; then
        PACKAGE_NAME=wazuh-indexer-"$VERSION"-"$REVISION"."$SUFFIX"."$EXT"
    else
        PACKAGE_NAME=wazuh-indexer_"$VERSION"-"$REVISION"_"$SUFFIX"."$EXT"
    fi
    if "$IS_MIN"; then
        PACKAGE_NAME=${PACKAGE_NAME/wazuh-indexer/wazuh-indexer-min}
    fi
}

# ====
# Naming convention for pre-release packages
# ====
function get_devel_name() {
    PREFIX=wazuh-indexer
    COMMIT_HASH=$GIT_COMMIT
    # Add -min to the prefix if corresponds
    if "$IS_MIN"; then
        PREFIX="$PREFIX"-min
    fi
    # Generate composed commit hash
    if [ -n "$PLUGINS_HASH" ] && [ -n "$REPORTING_HASH" ]; then
        COMMIT_HASH="$GIT_COMMIT"-"$PLUGINS_HASH"-"$REPORTING_HASH"
    fi
    PACKAGE_NAME="$PREFIX"_"$VERSION"-"$REVISION"_"$SUFFIX"_"$COMMIT_HASH"."$EXT"
}

# ====
# Naming convention control function
# ====
function get_package_name() {
    if "$IS_RELEASE"; then
        get_release_name
    else
        get_devel_name
    fi
}

# ====
# Main function
# ====
function main() {
    parse_args "${@}"

    get_package_name
    echo "$PACKAGE_NAME"
}

GIT_COMMIT=$(git rev-parse --short HEAD)
VERSION=$(bash build-scripts/product_version.sh)
main "${@}"
