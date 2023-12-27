#!/bin/bash

# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

set -ex

# Minimum required plugins
# plugins=(
#     "performance-analyzer"
#     "opensearch-security"
# )

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

# ====
# Usage
# ====
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

# ====
# Parse arguments
# ====
function parse_args() {

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
# Tar assemble
# ====
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

# ====
# RPM assemble
# ====
function assemble_rpm() {
    # Copy spec
    cp "distribution/packages/src/rpm/wazuh-indexer.rpm.spec" "${TMP_DIR}"
    # Copy performance analyzer service file
    mkdir -p "${TMP_DIR}"/usr/lib/systemd/system
    cp "distribution/packages/src/common/wazuh-indexer-performance-analyzer.service" "${TMP_DIR}"/usr/lib/systemd/system

    cd "${TMP_DIR}"
    local src_path="./usr/share/wazuh-indexer"
    PATH_CONF="./etc/wazuh-indexer"
    PATH_BIN="${src_path}/bin"

    # Extract min-package. Creates usr/, etc/ and var/ in the current directory
    echo "Extract ${ARTIFACT_BUILD_NAME} archive"
    rpm2cpio "${ARTIFACT_BUILD_NAME}" | cpio -imdv

    # Install plugins from Maven repository
    echo "Install plugins"
    for plugin in "${plugins[@]}"; do
        plugin_from_maven="org.opensearch.plugin:${plugin}:$VERSION.0"
        OPENSEARCH_PATH_CONF=$PATH_CONF "${PATH_BIN}/opensearch-plugin" install --batch --verbose "${plugin_from_maven}"
    done

    # Move performance-analyzer-rca to its final location
    local rca_src="${src_path}/plugins/opensearch-performance-analyzer/performance-analyzer-rca"
    local rca_dest="${src_path}"
    mv "${rca_src}" "${rca_dest}"

    # Set up configuration files
    cp $PATH_CONF/security/* $PATH_CONF/opensearch-security/
    cp $PATH_CONF/jvm.prod.options $PATH_CONF/jvm.options
    cp $PATH_CONF/opensearch.prod.yml $PATH_CONF/opensearch.yml

    rm -r $PATH_CONF/security
    rm $PATH_CONF/jvm.prod.options $PATH_CONF/opensearch.prod.yml

    # Remove symbolic links and bat files
    find . -type l -exec rm -rf {} \;
    find . -name "*.bat" -exec rm -rf {} \;

    # Generate final package
    local topdir
    local version
    local spec_file="wazuh-indexer.rpm.spec"
    topdir=$(pwd)
    version=$(cat ./usr/share/wazuh-indexer/VERSION)
    # TODO validate architecture
    rpmbuild --bb \
        --define "_topdir ${topdir}" \
        --define "_version ${version}" \
        --define "_architecture ${SUFFIX}" \
        ${spec_file}

    # Move to the root folder, copy the package and clean.
    cd ../../..
    package_name="wazuh-indexer-${version}-1.${SUFFIX}.${EXT}"
    cp "${TMP_DIR}/RPMS/${SUFFIX}/${package_name}" "${OUTPUT}/dist/"

    echo "Cleaning temporary ${TMP_DIR} folder"
    rm -r "artifacts/tmp"
    echo "After execution, shell path is $(pwd)"
    # Store package's name to file. Used by GH Action.
    echo "${package_name}" >"${OUTPUT}/artifact_name.txt"
}

# ====
# DEB assemble
# ====
function assemble_deb() {
    # Copy spec
    cp "distribution/packages/src/deb/Makefile" "${TMP_DIR}"
    cp "distribution/packages/src/deb/debmake_install.sh" "${TMP_DIR}"
    chmod a+x "${TMP_DIR}/debmake_install.sh"
    # Copy performance analyzer service file
    mkdir -p "${TMP_DIR}"/usr/lib/systemd/system
    cp "distribution/packages/src/common/wazuh-indexer-performance-analyzer.service" "${TMP_DIR}"/usr/lib/systemd/system

    cd "${TMP_DIR}"
    local src_path="./usr/share/wazuh-indexer"
    PATH_CONF="./etc/wazuh-indexer"
    PATH_BIN="${src_path}/bin"

    # Extract min-package. Creates usr/, etc/ and var/ in the current directory
    echo "Extract ${ARTIFACT_BUILD_NAME} archive"
    ar xf "${ARTIFACT_BUILD_NAME}" data.tar.gz
    tar zvxf data.tar.gz

    # Install plugins from Maven repository
    echo "Install plugins"
    for plugin in "${plugins[@]}"; do
        plugin_from_maven="org.opensearch.plugin:${plugin}:$VERSION.0"
        OPENSEARCH_PATH_CONF=$PATH_CONF "${PATH_BIN}/opensearch-plugin" install --batch --verbose "${plugin_from_maven}"
    done

    # Move performance-analyzer-rca to its final location
    local rca_src="${src_path}/plugins/opensearch-performance-analyzer/performance-analyzer-rca"
    local rca_dest="${src_path}"
    mv "${rca_src}" "${rca_dest}"

    # Set up configuration files
    cp $PATH_CONF/security/* $PATH_CONF/opensearch-security/
    cp $PATH_CONF/jvm.prod.options $PATH_CONF/jvm.options
    cp $PATH_CONF/opensearch.prod.yml $PATH_CONF/opensearch.yml

    rm -r $PATH_CONF/security
    rm $PATH_CONF/jvm.prod.options $PATH_CONF/opensearch.prod.yml

    # Remove symbolic links and bat files
    find . -type l -exec rm -rf {} \;
    find . -name "*.bat" -exec rm -rf {} \;

    # Generate final package
    local version
    version=$(cat ./usr/share/wazuh-indexer/VERSION)
    debmake \
        --fullname "Wazuh Team" \
        --email "hello@wazuh.com" \
        --invoke debuild \
        --package wazuh-indexer \
        --native \
        --revision 1 \
        --upstreamversion "${version}"

    # Move to the root folder, copy the package and clean.
    cd ../../..
    package_name="wazuh-indexer_${version}_${SUFFIX}.${EXT}"
    # debmake creates the package one level above
    cp "${TMP_DIR}/../${package_name}" "${OUTPUT}/dist/"

    echo "Cleaning temporary ${TMP_DIR} folder"
    rm -r "artifacts/tmp"
    echo "After execution, shell path is $(pwd)"
    # Store package's name to file. Used by GH Action.
    echo "${package_name}" >"${OUTPUT}/artifact_name.txt"
}

# ====
# Main function
# ====
function main() {
    parse_args "${@}"

    echo "Assembling OpenSearch for $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
    # wazuh-indexer-min_4.9.0-1-x64_78fcc3db6a5b470294319e48b58c3d715bee39d1.rpm
    ARTIFACT_BUILD_NAME=$(ls "${OUTPUT}/dist/" | grep "wazuh-indexer-min.*.$EXT")

    # Create temporal directory and copy the min package there for extraction
    TMP_DIR="${OUTPUT}/tmp/${TARGET}"
    mkdir -p "$TMP_DIR"
    cp "${OUTPUT}/dist/$ARTIFACT_BUILD_NAME" "${TMP_DIR}"

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
        assemble_deb
        ;;
    arm64.deb)
        assemble_deb
        ;;
    esac
}

main "${@}"
