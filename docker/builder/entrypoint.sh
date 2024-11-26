#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Set default values for environment variables
INDEXER_BRANCH=${INDEXER_BRANCH:-master}
INDEXER_PLUGINS_BRANCH=${INDEXER_PLUGINS_BRANCH:-master}
INDEXER_REPORTING_BRANCH=${INDEXER_REPORTING_BRANCH:-master}
REVISION=${REVISION:-0}
IS_STAGE=${IS_STAGE:-false}
DISTRIBUTION=${DISTRIBUTION:-tar}
ARCHITECTURE=${ARCHITECTURE:-x64}

# Function to clone repositories
clone_repositories() {
    echo "----------------------------------------"
    echo "Cloning Repositories"
    echo "----------------------------------------"
    git clone --branch "$INDEXER_BRANCH" https://github.com/wazuh/wazuh-indexer --depth 1 ~/wazuh-indexer
    git clone --branch "$INDEXER_PLUGINS_BRANCH" https://github.com/wazuh/wazuh-indexer-plugins --depth 1 ~/wazuh-indexer-plugins
    git clone --branch "$INDEXER_REPORTING_BRANCH" https://github.com/wazuh/wazuh-indexer-reporting --depth 1 ~/wazuh-indexer-reporting
}

# Function to build wazuh-indexer-plugins
build_plugins() {
    echo "----------------------------------------"
    echo "Building Plugins"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ~/wazuh-indexer-plugins/plugins/setup
    echo "Building setup plugin..."
    ./gradlew build -Dversion="$version" -Drevision="$revision" --no-daemon
    cd ~/wazuh-indexer-plugins/plugins/command-manager
    echo "Building command-manager plugin..."
    ./gradlew build -Dversion="$version" -Drevision="$revision" --no-daemon
}

# Function to build wazuh-indexer-reporting
build_reporting() {
    echo "----------------------------------------"
    echo "Building Reporting"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ~/wazuh-indexer-reporting
    echo "Building reporting..."
    ./gradlew build -Dversion="$version" -Drevision="$revision" --no-daemon
}

# Function to copy builds
copy_builds() {
    echo "----------------------------------------"
    echo "Copying Builds"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    mkdir -p ~/wazuh-indexer/artifacts/plugins
    echo "Copying setup plugin..."
    cp ~/wazuh-indexer-plugins/plugins/setup/build/distributions/wazuh-indexer-setup-"$version"."$revision".zip ~/wazuh-indexer/artifacts/plugins
    echo "Copying command-manager plugin..."
    cp ~/wazuh-indexer-plugins/plugins/command-manager/build/distributions/wazuh-indexer-command-manager-"$version"."$revision".zip ~/wazuh-indexer/artifacts/plugins
    echo "Copying reporting..."
    cp ~/wazuh-indexer-reporting/build/distributions/wazuh-indexer-reports-scheduler-"$version"."$revision".zip ~/wazuh-indexer/artifacts/plugins
}

# Function for packaging process
package_artifacts() {
    echo "----------------------------------------"
    echo "Packaging Artifacts"
    echo "----------------------------------------"
    local architecture="$1"
    local distribution="$2"
    local revision="$3"
    local is_stage="$4"

    local plugins_hash
    local reporting_hash
    local package_min_name
    local package_name

    cd ~/wazuh-indexer

    plugins_hash=$(cd ~/wazuh-indexer-plugins && git rev-parse --short HEAD)
    reporting_hash=$(cd ~/wazuh-indexer-reporting && git rev-parse --short HEAD)

    echo "Creating package minimum name..."
    package_min_name=$(bash build-scripts/baptizer.sh -m \
        -a "$architecture" \
        -d "$distribution" \
        -r "$revision" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        "$(if [ "$is_stage" = "true" ]; then echo "-x"; fi)")

    echo "Creating package name..."
    package_name=$(bash build-scripts/baptizer.sh \
        -a "$architecture" \
        -d "$distribution" \
        -r "$revision" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        "$(if [ "$is_stage" = "true" ]; then echo "-x"; fi)")

    echo "Building package..."
    bash build-scripts/build.sh -a "$architecture" -d "$distribution" -n "$package_min_name"
    echo "Assembling package..."
    bash build-scripts/assemble.sh -a "$architecture" -d "$distribution" -r "$revision"

    mkdir -p ~/artifacts/
    echo "Moving package to artifacts..."
    mv ~/wazuh-indexer/artifacts/dist/"$package_name" ~/artifacts/
}

# Function for cleanup
cleanup() {
    echo "----------------------------------------"
    echo "Cleaning Up"
    echo "----------------------------------------"
    rm -rf ~/wazuh-indexer
    rm -rf ~/wazuh-indexer-plugins
    rm -rf ~/wazuh-indexer-reporting
    echo "Cleanup completed."
}

# Main script execution
main() {
    echo "---------Starting Build Process---------"
    clone_repositories
    # Set version env var
    VERSION=$(cat ~/wazuh-indexer/VERSION)
    # Build and assemble the package
    build_plugins "$VERSION" "$REVISION"
    build_reporting "$VERSION" "$REVISION"
    copy_builds "$VERSION" "$REVISION"
    package_artifacts "$ARCHITECTURE" "$DISTRIBUTION" "$REVISION" "$IS_STAGE"
    # Clean the environment
    cleanup
    echo "----------------------------------------"
    echo "Build and Packaging Process Completed Successfully!"
    echo "----------------------------------------"
}

# Execute the main function
main
