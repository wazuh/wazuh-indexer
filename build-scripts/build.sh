#!/bin/bash

# ====
# Usage
# ====
function usage() {
    echo "Usage: $0 [args]"
    echo ""
    echo "Arguments:"
    echo -e "-q QUALIFIER\t[Optional] Version qualifier."
    echo -e "-s SNAPSHOT\t[Optional] Build a snapshot, default is 'false'."
    echo -e "-p PLATFORM\t[Optional] Platform, default is 'uname -s'."
    echo -e "-a ARCHITECTURE\t[Optional] Build architecture, default is 'uname -m'."
    echo -e "-d DISTRIBUTION\t[Optional] Distribution, default is 'tar'."
    echo -e "-b BRANCH\t[Optional] Branch from wazuh/wazuh to download the index template from, default is $(bash build-scripts/product_version.sh)"
    echo -e "-n NAME\t[optional] Package name, default is set automatically."
    echo -e "-o OUTPUT\t[Optional] Output path, default is 'artifacts'."
    echo -e "-m\t[Optional] Also publish the Maven artifacts of the project to OUTPUT/maven. The packages do not use them."
    echo -e "-h help"
}

# ====
# Parse arguments
# ====
function parse_args() {

    while getopts ":hmq:s:o:p:a:d:r:b:n:" arg; do
        case $arg in
        h)
            usage
            exit 1
            ;;
        q)
            QUALIFIER=$OPTARG
            ;;
        s)
            SNAPSHOT=$OPTARG
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
        n)
            NAME=$OPTARG
            ;;
        b)
            BRANCH=$OPTARG
            ;;
        m)
            MAVEN=true
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

    [ -z "$OUTPUT" ] && OUTPUT=artifacts
    [ -z "$SNAPSHOT" ] && SNAPSHOT=false
    [ -z "$MAVEN" ] && MAVEN=false
    [ -z "$PLATFORM" ] && PLATFORM=$(uname -s | awk '{print tolower($0)}')
    [ -z "$ARCHITECTURE" ] && ARCHITECTURE=$(uname -m)
    [ -z "$DISTRIBUTION" ] && DISTRIBUTION="tar"
    [ -z "$BRANCH" ] && BRANCH=$(bash build-scripts/product_version.sh)

    case $PLATFORM-$DISTRIBUTION-$ARCHITECTURE in
    linux-tar-x64 | darwin-tar-x64)
        PACKAGE="tar"
        EXT="tar.gz"
        TYPE="archives"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    linux-tar-arm64 | darwin-tar-arm64)
        PACKAGE="tar"
        EXT="tar.gz"
        TYPE="archives"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
        ;;
    linux-deb-x64)
        PACKAGE="deb"
        EXT="deb"
        TYPE="packages"
        TARGET="deb"
        SUFFIX="amd64"
        ;;
    linux-deb-arm64)
        PACKAGE="deb"
        EXT="deb"
        TYPE="packages"
        TARGET="arm64-deb"
        SUFFIX="arm64"
        ;;
    linux-rpm-x64)
        PACKAGE="rpm"
        EXT="rpm"
        TYPE="packages"
        TARGET="rpm"
        SUFFIX="x86_64"
        ;;
    linux-rpm-arm64)
        PACKAGE="rpm"
        EXT="rpm"
        TYPE="packages"
        TARGET="arm64-rpm"
        SUFFIX="aarch64"
        ;;
    windows-zip-x64)
        PACKAGE="zip"
        EXT="zip"
        TYPE="archives"
        TARGET="$PLATFORM-$PACKAGE"
        SUFFIX="$PLATFORM-x64"
        ;;
    windows-zip-arm64)
        PACKAGE="zip"
        EXT="zip"
        TYPE="archives"
        TARGET="$PLATFORM-arm64-$PACKAGE"
        SUFFIX="$PLATFORM-arm64"
        ;;
    *)
        echo "Unsupported platform-distribution-architecture combination: $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
        exit 1
        ;;
    esac
}

# ====
# Build function
# ====
function build() {
    local flags=(-Dbuild.snapshot="$SNAPSHOT" -Dbuild.version_qualifier="$QUALIFIER" -Pcrypto.standard=FIPS-140-3)

    if [ "$MAVEN" = true ]; then
        echo "Creating output directory $OUTPUT/maven/org/opensearch if it doesn't already exist"
        mkdir -p "$OUTPUT/maven/org/opensearch"

        # Build project and publish to maven local.
        echo "Building and publishing OpenSearch project to Maven Local"
        ./gradlew publishToMavenLocal "${flags[@]}"

        # Publish to existing test repo, using this to stage release versions of the artifacts that can be released from the same build.
        echo "Publishing OpenSearch to Test Repository"
        ./gradlew publishNebulaPublicationToTestRepository "${flags[@]}"

        # Copy maven publications to be promoted
        echo "Copying Maven publications to $OUTPUT/maven/org"
        cp -r ./build/local-test-repo/org/opensearch "${OUTPUT}"/maven/org
    fi

    # Assemble the distribution artifact, and build the ZIPs of the internally-built
    # plugins (not available on Maven Central), in one Gradle run. Only what the package
    # needs is built: the Maven publications (javadoc, sources, POMs of every module)
    # took most of the build time, and nothing in the package uses them.
    # see https://github.com/opensearch-project/OpenSearch/blob/main/settings.gradle#L34 for other distribution targets
    ./gradlew ":distribution:$TYPE:$TARGET:assemble" :plugins:workload-management:bundlePlugin "${flags[@]}"
}

# ====
# Main function
# ====
function main() {
    parse_args "${@}"

    echo "Building OpenSearch for $PLATFORM-$DISTRIBUTION-$ARCHITECTURE"
    build

    # Copy artifact to dist folder in bundle build output
    echo "Copying artifact to ${OUTPUT}/dist"
    local build_name
    build_name=$(ls "distribution/$TYPE/$TARGET/build/distributions/" | grep "wazuh-indexer-min.*$SUFFIX.$EXT")
    local package_name=${NAME:-$build_name}
    mkdir -p "${OUTPUT}/dist"
    cp "distribution/$TYPE/$TARGET/build/distributions/$build_name" "${OUTPUT}/dist/$package_name"

    # assemble.sh installs the internally-built plugins from here
    echo "Copying internal plugin ZIPs to ${OUTPUT}/internal-plugins"
    mkdir -p "${OUTPUT}/internal-plugins"
    cp plugins/workload-management/build/distributions/workload-management-*.zip "${OUTPUT}/internal-plugins/"
}

main "${@}"
