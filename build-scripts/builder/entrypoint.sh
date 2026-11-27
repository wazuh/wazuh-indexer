#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -ex

# Retry a command with exponential backoff.
# Usage: retry <max_attempts> <initial_delay_seconds> <command...>
retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local attempt=1

    until "$@"; do
        if (( attempt >= max_attempts )); then
            echo "ERROR: Command failed after ${max_attempts} attempts: $*" >&2
            return 1
        fi
        echo "Attempt ${attempt}/${max_attempts} failed. Retrying in ${delay}s..." >&2
        sleep "$delay"
        delay=$(( delay * 2 ))
        (( attempt++ ))
    done
}

RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-5}
RETRY_DELAY_GIT=${RETRY_DELAY_GIT:-10}
RETRY_DELAY_SNAPSHOTS=${RETRY_DELAY_SNAPSHOTS:-15}
RETRY_DELAY_GRADLE=${RETRY_DELAY_GRADLE:-30}

# Set default values for environment variables
INDEXER_PLUGINS_BRANCH=${INDEXER_PLUGINS_BRANCH:-main}
INDEXER_REPORTING_BRANCH=${INDEXER_REPORTING_BRANCH:-main}
SECURITY_ANALYTICS_BRANCH=${SECURITY_ANALYTICS_BRANCH:-main}
NOTIFICATIONS_BRANCH=${NOTIFICATIONS_BRANCH:-main}
ALERTING_BRANCH=${ALERTING_BRANCH:-main}
COMMON_UTILS_BRANCH=${COMMON_UTILS_BRANCH:-main}
ENGINE_TARBALL=${ENGINE_TARBALL:-}
REVISION=${REVISION:-0}
IS_STAGE=${IS_STAGE:-false}
DISTRIBUTION=${DISTRIBUTION:-rpm}
ARCHITECTURE=${ARCHITECTURE:-x64}
# Stage to run: all (default), build or package. See build-scripts/README.md.
BUILD_PHASE=${BUILD_PHASE:-all}

case "$BUILD_PHASE" in
all | build | package) ;;
*)
    echo "Error: invalid BUILD_PHASE '${BUILD_PHASE}', expected all, build or package." >&2
    exit 1
    ;;
esac

# Define repositories as an associative array
declare -A REPOS=(
    [PLUGINS]="wazuh-indexer-plugins|$INDEXER_PLUGINS_BRANCH"
    [REPORTING]="wazuh-indexer-reporting|$INDEXER_REPORTING_BRANCH"
    [SECURITY_ANALYTICS]="wazuh-indexer-security-analytics|$SECURITY_ANALYTICS_BRANCH"
    [COMMON_UTILS]="wazuh-indexer-common-utils|$COMMON_UTILS_BRANCH"
    [NOTIFICATIONS]="wazuh-indexer-notifications|$NOTIFICATIONS_BRANCH"
    [ALERTING]="wazuh-indexer-alerting|$ALERTING_BRANCH"
)

# Set repo directory variables
PLUGINS_REPO_DIR="/repositories/wazuh-indexer-plugins"
REPORTING_REPO_DIR="/repositories/wazuh-indexer-reporting"
SECURITY_ANALYTICS_REPO_DIR="/repositories/wazuh-indexer-security-analytics"
NOTIFICATIONS_REPO_DIR="/repositories/wazuh-indexer-notifications"
ALERTING_REPO_DIR="/repositories/wazuh-indexer-alerting"
COMMON_UTILS_REPO_DIR="/repositories/wazuh-indexer-common-utils"

# Function to clone repositories
clone_repositories() {
    echo "----------------------------------------"
    echo "Cloning Repositories"
    echo "----------------------------------------"

    local repo_name 
    local repo_url 
    local branch 
    local repo_dir_var 
    local repo_dir

    for key in "${!REPOS[@]}"; do
        IFS='|' read -r repo_name branch <<< "${REPOS[$key]}"
        repo_dir_var="${key}_REPO_DIR"
        repo_dir="${!repo_dir_var}"
        repo_url="https://github.com/wazuh/$repo_name"

        if [ ! -d "$repo_dir/.git" ]; then
            retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GIT" git clone --depth 1 "$repo_url" "$repo_dir"
        fi
        # Resolve a branch, tag, or commit SHA (volumes persist across runs).
        retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GIT" git -C "$repo_dir" fetch --depth 1 origin "$branch"
        git -C "$repo_dir" checkout --detach FETCH_HEAD
    done
}

# Invoke the script to download the snapshots
download_snapshots() {
    echo "----------------------------------------"
    echo "Downloading Snapshots"
    echo "----------------------------------------"

    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_SNAPSHOTS" bash ~/build-scripts/download_snapshots.sh \
        --env "${CTI_API_URL:-https://api.pre.cloud.wazuh.com/api/v1}" \
        --output-dir ~/artifacts/snapshots
}

# Function to build wazuh-indexer-plugins
build_plugins() {
    echo "----------------------------------------"
    echo "Building Plugins"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${PLUGINS_REPO_DIR}
    echo "Building setup and content-manager plugins..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to build wazuh-indexer-reporting
build_reporting() {
    echo "----------------------------------------"
    echo "Building Reporting"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${REPORTING_REPO_DIR}
    echo "Building reporting..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to build wazuh-indexer-security-analytics
build_security_analytics() {
    echo "----------------------------------------"
    echo "Building Security Analytics"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${SECURITY_ANALYTICS_REPO_DIR}

    echo "Building security analytics commons..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew wazuh-indexer-security-analytics-commons:publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check

    echo "Building security analytics..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to build wazuh-indexer-common-utils
build_common_utils() {
    echo "----------------------------------------"
    echo "Building Common Utils"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${COMMON_UTILS_REPO_DIR}
    echo "Building common-utils..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to build wazuh-indexer-notifications
build_notifications() {
    echo "----------------------------------------"
    echo "Building Notifications"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${NOTIFICATIONS_REPO_DIR}/notifications
    echo "Building notifications..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to build wazuh-indexer-alerting
build_alerting() {
    echo "----------------------------------------"
    echo "Building Alerting"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    cd ${ALERTING_REPO_DIR}
    echo "Building alerting..."
    retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_GRADLE" ./gradlew publishToMavenLocal -Dversion="$version" -Drevision="$revision" --no-daemon -x check
}

# Function to copy builds
copy_builds() {
    echo "----------------------------------------"
    echo "Copying Builds"
    echo "----------------------------------------"
    local version="$1"
    local revision="$2"
    local v="${version}.${revision}"
    local m2="/var/m2/com/wazuh"
    mkdir -p ~/artifacts/plugins

    # All plugins are published to Maven local — iterate and copy
    local maven_plugins=(
        "wazuh-indexer-setup"
        "wazuh-indexer-content-manager"
        "wazuh-indexer-reports-scheduler"
        "wazuh-indexer-security-analytics"
        "wazuh-indexer-notifications-core"
        "wazuh-indexer-notifications"
        "wazuh-indexer-alerting"
    )
    for artifact in "${maven_plugins[@]}"; do
        echo "Copying ${artifact}..."
        cp "${m2}/${artifact}/${v}/${artifact}-${v}.zip" ~/artifacts/plugins
    done
}

# Fails early if the Wazuh Engine tarball is not available to the container.
check_engine_tarball() {
    if [ -z "$ENGINE_TARBALL" ] || [ ! -f /tmp/engine-tarball.tar.gz ]; then
        echo "Error: wazuh-engine tarball is required but was not provided or is not accessible at /tmp/engine-tarball.tar.gz."
        exit 1
    fi
}

# Function to set up the Wazuh Engine tarball
setup_engine_tarball() {
    check_engine_tarball
    echo "----------------------------------------"
    echo "Setting up Wazuh Engine tarball"
    echo "----------------------------------------"
    local tarball_name dest
    tarball_name=$(basename "$ENGINE_TARBALL")
    dest=~/artifacts/engine/"$tarball_name"
    mkdir -p ~/artifacts/engine
    # Skip the copy if the source and destination are the same file.
    if [ /tmp/engine-tarball.tar.gz -ef "$dest" ]; then
        echo "Engine tarball already in place at artifacts/engine/$tarball_name"
    else
        cp /tmp/engine-tarball.tar.gz "$dest"
        echo "Engine tarball copied to artifacts/engine/$tarball_name"
    fi
}

# Records the commit of each repository in artifacts/commits.txt, so that the
# package stage can name and assemble the package without the clones.
# Format: "<repo> <full sha> <short sha>", in build order, wazuh-indexer last.
# The short sha is kept as git computed it: its length depends on the clone.
# Variables stay in lower case: the release tooling parses the upper-case
# *_HASH= markers that assemble.sh prints, and the first occurrence wins.
write_commits_file() {
    echo "----------------------------------------"
    echo "Recording repository commits"
    echo "----------------------------------------"
    local commits_file=~/artifacts/commits.txt
    local entry repo_name repo_dir full short
    mkdir -p ~/artifacts
    : >"$commits_file"
    for entry in \
        "wazuh-indexer-common-utils|${COMMON_UTILS_REPO_DIR}" \
        "wazuh-indexer-alerting|${ALERTING_REPO_DIR}" \
        "wazuh-indexer-security-analytics|${SECURITY_ANALYTICS_REPO_DIR}" \
        "wazuh-indexer-notifications|${NOTIFICATIONS_REPO_DIR}" \
        "wazuh-indexer-reporting|${REPORTING_REPO_DIR}" \
        "wazuh-indexer-plugins|${PLUGINS_REPO_DIR}" \
        "wazuh-indexer|${HOME}"; do
        IFS='|' read -r repo_name repo_dir <<<"$entry"
        full=$(git -C "$repo_dir" rev-parse HEAD)
        short=$(git -C "$repo_dir" rev-parse --short HEAD)
        echo "$repo_name $full $short" >>"$commits_file"
    done
}

# Builds the OpenSearch core and leaves its distribution in artifacts/core under
# the Gradle name. The package stage gives it the final name.
build_core() {
    cd ~
    # Drop the outputs of previous runs (the bind-mounted repository persists
    # locally). build.sh does not stop on a failed Gradle command, so an old
    # distribution or plugin zip left here could pass for a fresh one.
    rm -rf ~/artifacts/dist ~/artifacts/tmp ~/artifacts/core
    rm -rf distribution/archives/*/build/distributions \
        distribution/packages/*/build/distributions \
        plugins/workload-management/build/distributions

    echo "Building package..."
    bash build-scripts/build.sh -a "$ARCHITECTURE" -d "$DISTRIBUTION"

    local cores=()
    local file
    shopt -s nullglob
    for file in ~/artifacts/dist/wazuh-indexer-min*; do
        cores+=("$file")
    done
    shopt -u nullglob
    if [ "${#cores[@]}" -ne 1 ]; then
        echo "Error: expected exactly one core distribution in artifacts/dist, found ${#cores[@]}."
        exit 1
    fi
    mkdir -p ~/artifacts/core
    mv "${cores[0]}" ~/artifacts/core/
}

# Reads artifacts/commits.txt into the variables used to name and assemble the
# package. Fails if the core was built from a different indexer commit than the
# one checked out, because the package name and the configuration files come
# from the checkout.
read_commits_file() {
    local repo full short head
    while read -r repo full short; do
        case "$repo" in
        wazuh-indexer-plugins) plugins_hash=$short ;;
        wazuh-indexer-reporting) reporting_hash=$short ;;
        wazuh-indexer-security-analytics) security_analytics_hash=$short ;;
        wazuh-indexer-notifications) notifications_hash=$short ;;
        wazuh-indexer-alerting) alerting_hash=$short ;;
        wazuh-indexer) indexer_full=$full ;;
        esac
    done < <(grep -v '^#' ~/artifacts/commits.txt)

    head=$(git -C ~ rev-parse HEAD)
    if [ "$indexer_full" != "$head" ]; then
        echo "Error: the build stage ran on wazuh-indexer ${indexer_full}, but ${head} is checked out."
        exit 1
    fi
}

# Gives the core distribution its final min name in artifacts/dist.
prepare_dist() {
    echo "----------------------------------------"
    echo "Packaging Artifacts"
    echo "----------------------------------------"
    cd ~
    # Drop packages from previous runs (the bind-mounted artifacts/ persists
    # locally); assemble.sh matches wazuh-indexer-min* by glob and breaks on a
    # stale match.
    rm -rf ~/artifacts/dist ~/artifacts/tmp

    echo "Creating package minimum name..."
    package_min_name=$(bash build-scripts/baptizer.sh -m \
        -a "$ARCHITECTURE" \
        -d "$DISTRIBUTION" \
        -r "$REVISION" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        -s "$security_analytics_hash" \
        -n "$notifications_hash" \
        -t "$alerting_hash" \
        "$(if [ "$IS_STAGE" = "true" ]; then echo "-x"; fi)")

    mkdir -p ~/artifacts/dist
    cp ~/artifacts/core/wazuh-indexer-min* ~/artifacts/dist/"$package_min_name"
}

# Assembles the package from the min distribution and the Wazuh plugins.
assemble_package() {
    cd ~
    echo "Assembling package..."
    bash build-scripts/assemble.sh \
        -a "$ARCHITECTURE" \
        -d "$DISTRIBUTION" \
        -r "$REVISION" \
        -o "$(pwd)/artifacts" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        -s "$security_analytics_hash" \
        -n "$notifications_hash" \
        -t "$alerting_hash"
}

# Build stage: clone the repositories, build the plugins and the OpenSearch core.
run_build_stage() {
    clone_repositories
    # Set version env var
    VERSION=$(bash ~/build-scripts/product_version.sh)
    # Order matters
    build_common_utils "$VERSION" "$REVISION"
    build_alerting "$VERSION" "$REVISION"
    build_security_analytics "$VERSION" "$REVISION"
    build_notifications "$VERSION" "$REVISION"
    build_reporting "$VERSION" "$REVISION"
    build_plugins "$VERSION" "$REVISION"

    copy_builds "$VERSION" "$REVISION"
    write_commits_file
    build_core
}

# Package stage: set up the engine and the snapshots, name and assemble the
# package from the stage contract. It does not clone or compile anything.
run_package_stage() {
    VERSION=$(bash ~/build-scripts/product_version.sh)
    bash ~/build-scripts/check_stage_contract.sh \
        -d "$DISTRIBUTION" -a "$ARCHITECTURE" -r "$REVISION" -v "$VERSION" -w ~
    setup_engine_tarball
    download_snapshots
    read_commits_file
    prepare_dist
    assemble_package
}

# Main script execution
main() {
    echo "---------Starting Build Process---------"
    case "$BUILD_PHASE" in
    all)
        # Fail before compiling if the engine is missing.
        check_engine_tarball
        run_build_stage
        run_package_stage
        ;;
    build)
        run_build_stage
        ;;
    package)
        run_package_stage
        ;;
    esac

    # Clean the environment
    echo "----------------------------------------"
    if [ "$BUILD_PHASE" = "build" ]; then
        echo "Build Stage Completed Successfully!"
    else
        echo "Build and Packaging Process Completed Successfully!"
    fi
    echo "----------------------------------------"
}

# Execute the main function
main
