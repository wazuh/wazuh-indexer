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

# ====
# Build cache (opt-in, see build-scripts/cache/README.md)
#
# builder.sh, on the host, writes artifacts/cache/keys and places the cache hits in
# artifacts/cache/restore/<name>/ before this container starts. A restored artifact
# replaces its build. An artifact built here is copied to artifacts/cache/publish/<name>/
# for builder.sh to publish. Without the keys file everything is built, as before.
# ====
CACHE_ROOT=~/artifacts/cache
CACHE_KEYS="${CACHE_ROOT}/keys"

cache_enabled() {
    [ -f "$CACHE_KEYS" ]
}

# Prints a column of the keys file line of an artifact: 2 is the key, 3 the commit.
cache_field() {
    awk -v name="$1" -v col="$2" '$1 == name { print $col }' "$CACHE_KEYS"
}

# Succeeds when the commit a plugin repository is at is the one its key was computed
# for. Otherwise the cache is not used for it, in either direction.
cache_commit_matches() {
    local name="$1" repo_dir="$2" expected
    expected=$(cache_field "$name" 3)
    if [ "$(git -C "$repo_dir" rev-parse HEAD)" != "$expected" ]; then
        echo "WARNING: ${name} is at $(git -C "$repo_dir" rev-parse HEAD), not at ${expected}; not using the cache for it"
        return 1
    fi
}

# Succeeds when artifacts/cache/restore/<name>/ holds the entry of the expected key.
cache_restored() {
    local name="$1" dir="${CACHE_ROOT}/restore/$1" key
    cache_enabled || return 1
    key=$(cache_field "$name" 2)
    [ -n "$key" ] && [ -f "$dir/manifest.json" ] && [ "$(jq -r .key "$dir/manifest.json")" = "$key" ]
}

# Starts the publish copy of an artifact with its manifest.
cache_publish_dir() {
    local name="$1" commit="$2" dir="${CACHE_ROOT}/publish/$1"
    rm -rf "$dir"
    mkdir -p "$dir"
    jq -n \
        --arg name "$name" \
        --arg key "$(cache_field "$name" 2)" \
        --arg commit "$commit" \
        --arg built_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg java "$(java -version 2>&1 | head -n 1)" \
        --arg arch "$(uname -m)" \
        '{name: $name, key: $key, commit: $commit, built_at: $built_at, toolchain: {java: $java, machine: $arch}}' \
        >"$dir/manifest.json"
    echo "$dir"
}

# Restores a plugin repository from the cache or builds it. A restored entry holds the
# Maven local publications of the repository (artifact zips, jars and POMs), which is all
# that copy_builds and the repositories built after it read.
# Usage: build_or_restore <name> <repo dir> <build function>
build_or_restore() {
    local name="$1" repo_dir="$2" build_function="$3" v="${VERSION}.${REVISION}"
    local use_cache=false
    if cache_enabled && cache_commit_matches "$name" "$repo_dir"; then
        use_cache=true
    fi

    if [ "$use_cache" = true ] && cache_restored "$name"; then
        echo "----------------------------------------"
        echo "Cache hit: ${name} ($(cache_field "$name" 2)), restoring instead of building"
        echo "----------------------------------------"
        cp -a "${CACHE_ROOT}/restore/${name}/m2/." /var/m2/
        return
    fi
    if cache_enabled; then
        echo "Cache miss: ${name} ($(cache_field "$name" 2))"
    fi

    local marker
    marker=$(mktemp)
    "$build_function" "$VERSION" "$REVISION"

    if [ "$use_cache" = true ]; then
        # What this build published to Maven local: the version directories with files
        # newer than the marker, and the metadata of their artifacts.
        local dir published
        dir=$(cache_publish_dir "$name" "$(git -C "$repo_dir" rev-parse HEAD)")
        published=$(cd /var/m2 && find com/wazuh -type f -newer "$marker" -path "*/${v}/*" -printf '%h\n' | sort -u)
        if [ -z "$published" ]; then
            echo "ERROR: ${name} published nothing to Maven local for version ${v}"
            exit 1
        fi
        local version_dir
        for version_dir in $published; do
            mkdir -p "$dir/m2/$version_dir"
            cp -a "/var/m2/$version_dir/." "$dir/m2/$version_dir/"
            if [ -f "/var/m2/$(dirname "$version_dir")/maven-metadata-local.xml" ]; then
                cp -a "/var/m2/$(dirname "$version_dir")/maven-metadata-local.xml" "$dir/m2/$(dirname "$version_dir")/"
            fi
        done
        echo "Cache: ${name} built, ready to publish ($(echo "$published" | tr '\n' ' '))"
    fi
    rm -f "$marker"
}

# Function to set up the Wazuh Engine tarball
setup_engine_tarball() {
    if [ -z "$ENGINE_TARBALL" ] || [ ! -f /tmp/engine-tarball.tar.gz ]; then
        echo "Error: wazuh-engine tarball is required but was not provided or is not accessible at /tmp/engine-tarball.tar.gz."
        exit 1
    fi
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

# Function for packaging process
package_artifacts() {
    echo "----------------------------------------"
    echo "Packaging Artifacts"
    echo "----------------------------------------"
    # Drop packages from previous runs (the bind-mounted artifacts/ persists
    # locally); assemble.sh matches wazuh-indexer-min* by glob and breaks on a
    # stale match.
    rm -rf ~/artifacts/dist ~/artifacts/tmp ~/artifacts/internal-plugins

    local architecture="$1"
    local distribution="$2"
    local revision="$3"
    local is_stage="$4"

    local plugins_hash
    local reporting_hash
    local security_analytics_hash
    local notifications_hash
    local alerting_hash
    local package_min_name

    plugins_hash=$(cd ${PLUGINS_REPO_DIR} && git rev-parse --short HEAD)
    reporting_hash=$(cd ${REPORTING_REPO_DIR} && git rev-parse --short HEAD)
    security_analytics_hash=$(cd ${SECURITY_ANALYTICS_REPO_DIR} && git rev-parse --short HEAD)
    notifications_hash=$(cd ${NOTIFICATIONS_REPO_DIR} && git rev-parse --short HEAD)
    alerting_hash=$(cd ${ALERTING_REPO_DIR} && git rev-parse --short HEAD)

    cd ~

    echo "Creating package minimum name..."
    package_min_name=$(bash build-scripts/baptizer.sh -m \
        -a "$architecture" \
        -d "$distribution" \
        -r "$revision" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        -s "$security_analytics_hash" \
        -n "$notifications_hash" \
        -t "$alerting_hash" \
        "$(if [ "$is_stage" = "true" ]; then echo "-x"; fi)")

    # The core entry stores the min package under a fixed name: its build name carries
    # the commits of the build that produced it, so it is named after this build here.
    local core="core-${distribution}-${architecture}"
    if cache_restored "$core"; then
        echo "----------------------------------------"
        echo "Cache hit: ${core} ($(cache_field "$core" 2)), restoring instead of building"
        echo "----------------------------------------"
        mkdir -p ~/artifacts/dist ~/artifacts/internal-plugins
        cp "${CACHE_ROOT}/restore/${core}"/min/wazuh-indexer-min.* ~/artifacts/dist/"$package_min_name"
        cp "${CACHE_ROOT}/restore/${core}"/internal-plugins/* ~/artifacts/internal-plugins/
    else
        if cache_enabled; then
            echo "Cache miss: ${core} ($(cache_field "$core" 2))"
        fi
        echo "Building package..."
        bash build-scripts/build.sh -a "$architecture" -d "$distribution" -n "$package_min_name"
        if cache_enabled; then
            local dir
            dir=$(cache_publish_dir "$core" "$(git rev-parse HEAD)")
            mkdir -p "$dir/min" "$dir/internal-plugins"
            cp ~/artifacts/dist/"$package_min_name" "$dir/min/wazuh-indexer-min.${package_min_name##*.}"
            cp ~/artifacts/internal-plugins/* "$dir/internal-plugins/"
        fi
    fi
    echo "Assembling package..."
    bash build-scripts/assemble.sh \
        -a "$architecture" \
        -d "$distribution" \
        -r "$revision" \
        -o "$(pwd)/artifacts" \
        -l "$plugins_hash" \
        -e "$reporting_hash" \
        -s "$security_analytics_hash" \
        -n "$notifications_hash" \
        -t "$alerting_hash"

}

# Main script execution
main() {
    echo "---------Starting Build Process---------"
    clone_repositories
    # Set version env var
    VERSION=$(bash ~/build-scripts/product_version.sh)
    # Build and assemble the package
    download_snapshots
    # Order matters
    build_or_restore wazuh-indexer-common-utils "$COMMON_UTILS_REPO_DIR" build_common_utils
    build_or_restore wazuh-indexer-alerting "$ALERTING_REPO_DIR" build_alerting
    build_or_restore wazuh-indexer-security-analytics "$SECURITY_ANALYTICS_REPO_DIR" build_security_analytics
    build_or_restore wazuh-indexer-notifications "$NOTIFICATIONS_REPO_DIR" build_notifications
    build_or_restore wazuh-indexer-reporting "$REPORTING_REPO_DIR" build_reporting
    build_or_restore wazuh-indexer-plugins "$PLUGINS_REPO_DIR" build_plugins

    copy_builds "$VERSION" "$REVISION"
    setup_engine_tarball
    package_artifacts "$ARCHITECTURE" "$DISTRIBUTION" "$REVISION" "$IS_STAGE"

    # Clean the environment
    echo "----------------------------------------"
    echo "Build and Packaging Process Completed Successfully!"
    echo "----------------------------------------"
}

# Execute the main function
main
