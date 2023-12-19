#!/bin/bash

# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

set -ex

plugins=(
    "alerting" # "opensearch-alerting"
    "opensearch-job-scheduler"
    "opensearch-anomaly-detection" # requires "opensearch-job-scheduler"
    "asynchronous-search" # "opensearch-asynchronous-search"
    "opensearch-cross-cluster-replication"
    "geospatial" # "opensearch-geospatial"
    "opensearch-index-management"
    "opensearch-knn"
    "opensearch-ml-plugin" # "opensearch-ml"
    "neural-search" # "opensearch-neural-search"
    "opensearch-notifications-core"
    "notifications" # "opensearch-notifications" requires "opensearch-notifications-core"
    "opensearch-observability"
    "performance-analyzer" # "opensearch-performance-analyzer"
    "opensearch-reports-scheduler"
    "opensearch-security"
    "opensearch-security-analytics"
    "opensearch-sql-plugin" # "opensearch-sql"
)

function usage() {
    echo "Usage: $0 [args]"
    echo ""
    echo "Arguments:"
    echo -e "-v VERSION\t[Required] OpenSearch version."
    echo -e "-q QUALIFIER\t[Optional] Version qualifier."
    echo -e "-p PLATFORM\t[Optional] Platform, default is 'uname -s'."
    echo -e "-a ARCHITECTURE\t[Optional] Build architecture, default is 'uname -m'."
    echo -e "-d DISTRIBUTION\t[Optional] Distribution, default is 'tar'."
    echo -e "-o OUTPUT\t[Optional] Output path, default is 'artifacts'."
    echo -e "-h help"
}

while getopts ":h:v:q:o:p:a:d:" arg; do
    case $arg in
    h)
        usage
        exit 1
        ;;
    v)
        VERSION=$OPTARG
        ;;
    q)
        QUALIFIER=$OPTARG
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
        # TYPE="archives"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    linux-tar-arm64 | darwin-tar-arm64)
        PACKAGE="tar"
        EXT="tar.gz"
        # TYPE="archives"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
        ;;
    linux-deb-x64)
        PACKAGE="deb"
        EXT="deb"
        # TYPE="packages"
        TARGET="deb"
        SUFFIX="amd64"
        ;;
    linux-deb-arm64)
        PACKAGE="deb"
        EXT="deb"
        # TYPE="packages"
        TARGET="arm64-deb"
        SUFFIX="arm64"
        ;;
    linux-rpm-x64)
        PACKAGE="rpm"
        EXT="rpm"
        # TYPE="packages"
        TARGET="rpm"
        SUFFIX="x86_64"
        ;;
    linux-rpm-arm64)
        PACKAGE="rpm"
        EXT="rpm"
        # TYPE="packages"
        TARGET="arm64-rpm"
        SUFFIX="aarch64"
        ;;
    # windows-zip-x64)
    #     PACKAGE="zip"
    #     EXT="zip"
    #     # TYPE="archives"
    #     TARGET="$PLATFORM-$PACKAGE"
    #     SUFFIX="$PLATFORM-x64"
    #     ;;
    # windows-zip-arm64)
    #     PACKAGE="zip"
    #     EXT="zip"
    #     # TYPE="archives"
    #     TARGET="$PLATFORM-arm64-$PACKAGE"
    #     SUFFIX="$PLATFORM-arm64"
    #     ;;
    *)
        echo "Unsupported platform-distribution-architecture combination: $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
        exit 1
        ;;
esac

echo "Assembling OpenSearch for $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"

ARTIFACT_BUILD_NAME=$(ls "${OUTPUT}/dist/" | grep "wazuh-indexer-min.*$SUFFIX.$EXT")
# [WAZUH] Used by the GH workflow to upload the artifact
echo "$ARTIFACT_BUILD_NAME" >"$OUTPUT/artifact_name.txt"

# Create temporal directory and copy the min package there for extraction
TMP_DIR="${OUTPUT}/tmp/${TARGET}"
mkdir -p "$TMP_DIR"
cp "${OUTPUT}/dist/$ARTIFACT_BUILD_NAME" "${TMP_DIR}"

function assemble_tar() {
    cd "${TMP_DIR}"
    PATH_CONF="./config"
    PATH_BIN="./bin"

    # Step 1: extract
    echo "Extract ${ARTIFACT_BUILD_NAME} archive"
    tar -zvxf "${ARTIFACT_BUILD_NAME}"
    cd "$(ls -d wazuh-indexer-*/)"

    # Step 2: install plugins
    echo "Install plugins"
    for plugin in "${plugins[@]}"; do
        plugin_from_maven="org.opensearch.plugin:${plugin}:$VERSION.0"
        "${PATH_BIN}/opensearch-plugin" install --batch --verbose "${plugin_from_maven}"
    done

    # Step 3: swap configuration files
    cp $PATH_CONF/security/* $PATH_CONF/opensearch-security/
    cp $PATH_CONF/jvm.prod.options $PATH_CONF/jvm.options
    cp $PATH_CONF/opensearch.prod.yml $PATH_CONF/opensearch.yml

    rm -r $PATH_CONF/security
    rm $PATH_CONF/jvm.prod.options $PATH_CONF/opensearch.prod.yml

    # Step 4: pack
    archive_name="wazuh-indexer-$(cat VERSION)"
    cd ..
    tar -cvf "${archive_name}-${SUFFIX}.${EXT}" "${archive_name}"
    cd ../../..
    cp "${TMP_DIR}/${archive_name}-${SUFFIX}.${EXT}" "${OUTPUT}/dist/"

    echo "Cleaning temporary ${TMP_DIR} folder"
    rm -r "${TMP_DIR}"
    echo "After execution, shell path is $(pwd)"
}


function assemble_rpm() {
    cd "${TMP_DIR}"
    PATH_CONF="./etc/wazuh-indexer"
    PATH_BIN="./usr/share/wazuh-indexer/bin"

    # Step 1: extract. Create usr/, etc/ and var/
    echo "Extract ${ARTIFACT_BUILD_NAME} archive"
    rpm2cpio "${ARTIFACT_BUILD_NAME}" | cpio -imdv 
    cd "$(ls -d wazuh-indexer-*/)"

    # Step 2: install plugins
    echo "Install plugins"
    for plugin in "${plugins[@]}"; do
        plugin_from_maven="org.opensearch.plugin:${plugin}:$VERSION.0"
        OPENSEARCH_PATH_CONF=$PATH_CONF "${PATH_BIN}/opensearch-plugin" install --batch --verbose "${plugin_from_maven}"
    done

    # Step 3: swap configuration files
    cp $PATH_CONF/security/* $PATH_CONF/opensearch-security/
    cp $PATH_CONF/jvm.prod.options $PATH_CONF/jvm.options
    cp $PATH_CONF/opensearch.prod.yml $PATH_CONF/opensearch.yml

    rm -r $PATH_CONF/security
    rm $PATH_CONF/jvm.prod.options $PATH_CONF/opensearch.prod.yml

    # Step 4: pack
    # archive_name="wazuh-indexer-$(cat VERSION)"
    # rpmbuild --bb \
    #     --define "_topdir $(pwd)" \
    #     --define "_version $(cat ./usr/share/wazuh-indexer/VERSION)" \
    #     --define "_architecture ${ARCHITECTURE}" \
    #     "${RPM_SPEC}"

}

case $SUFFIX.$EXT in
    linux-arm64.tar.gz)
        assemble_tar
        ;;
    linux-x64.tar.gz)
        assemble_tar
        ;;
    aarch64.rpm)
        assemble_rpm
        ;;
    x86_64.rpm)
        assemble_rpm
        ;;
    amd64.deb)
        ;;
    arm64.deb)
        ;;
esac
