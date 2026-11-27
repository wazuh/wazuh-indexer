#!/bin/bash

# Start container with required tools to build packages
# Requires Docker
# Script usage: bash ./builder.sh

set -e

# ====
# Checks that the script is run from the intended location
# ====
function check_project_root_folder() {
    current=$(basename "$(pwd)")

    if [[ "$1" != "./builder.sh" && "$1" != "builder.sh" ]]; then
        echo "Run the script from its location"
        usage
        exit 1
    fi
    # Change working directory to the root of the repository
    cd ../..
}

# ====
# Parse arguments
# ====
function parse_args() {

    while getopts ":p:r:s:n:t:c:R:S:d:a:e:C:PDh" arg; do
        case $arg in
        h)
            usage
            exit 1
            ;;
        p)
            INDEXER_PLUGINS_BRANCH=$OPTARG
            ;;
        r)
            INDEXER_REPORTING_BRANCH=$OPTARG
            ;;
        s)
            SECURITY_ANALYTICS_BRANCH=$OPTARG
            ;;
        n)
            NOTIFICATIONS_BRANCH=$OPTARG
            ;;
        t)
            ALERTING_BRANCH=$OPTARG
            ;;
        c)
            COMMON_UTILS_BRANCH=$OPTARG
            ;;
        e)
            ENGINE_TARBALL=$OPTARG
            ;;
        R)
            REVISION=$OPTARG
            ;;
        S)
            IS_STAGE=$OPTARG
            ;;
        d)
            DISTRIBUTION=$OPTARG
            ;;
        a)
            ARCHITECTURE=$OPTARG
            ;;
        C)
            CACHE_STORE=$OPTARG
            ;;
        P)
            CACHE_PUBLISH=true
            ;;
        D)
            DESTROY=true
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

    ## Set defaults:
    [ -z "$INDEXER_PLUGINS_BRANCH" ] && INDEXER_PLUGINS_BRANCH="main"
    [ -z "$INDEXER_REPORTING_BRANCH" ] && INDEXER_REPORTING_BRANCH="main"
    [ -z "$SECURITY_ANALYTICS_BRANCH" ] && SECURITY_ANALYTICS_BRANCH="main"
    [ -z "$NOTIFICATIONS_BRANCH" ] && NOTIFICATIONS_BRANCH="main"
    [ -z "$ALERTING_BRANCH" ] && ALERTING_BRANCH="main"
    [ -z "$COMMON_UTILS_BRANCH" ] && COMMON_UTILS_BRANCH="main"
    [ -z "$REVISION" ] && REVISION="0"
    [ -z "$IS_STAGE" ] && IS_STAGE="false"
    [ -z "$DISTRIBUTION" ] && DISTRIBUTION="rpm"
    [ -z "$ARCHITECTURE" ] && ARCHITECTURE="x64"
    [ -z "$DESTROY" ] && DESTROY=false
    [ -z "$CACHE_PUBLISH" ] && CACHE_PUBLISH=false
    if [ "$CACHE_PUBLISH" = true ] && [ -z "$CACHE_STORE" ]; then
        echo "Error: -P requires -C STORE."
        exit 1
    fi
}

# ====
# Displays usage
# ====
function usage() {
    echo "Usage: $0 [args]"
    echo ""
    echo "Arguments:"
    echo -e "-p INDEXER_PLUGINS_BRANCH\t[Optional] wazuh-indexer-plugins repo branch, default is 'main'."
    echo -e "-r INDEXER_REPORTING_BRANCH\t[Optional] wazuh-indexer-reporting repo branch, default is 'main'."
    echo -e "-s SECURITY_ANALYTICS_BRANCH\t[Optional] wazuh-indexer-security-analytics repo branch, default is 'main'."
    echo -e "-n NOTIFICATIONS_BRANCH\t\t[Optional] wazuh-indexer-notifications repo branch, default is 'main'."
    echo -e "-t ALERTING_BRANCH\t\t[Optional] wazuh-indexer-alerting repo branch, default is 'main'."
    echo -e "-c COMMON_UTILS_BRANCH\t\t[Optional] wazuh-indexer-common-utils repo branch, default is 'main'."
    echo -e "-e ENGINE_TARBALL\t\t[Required] Path to wazuh-engine tarball (.tar.gz) on the host."
    echo -e "-R REVISION\t[Optional] Package revision, default is '0'."
    echo -e "-S STAGE\t[Optional] Staging build, default is 'false'."
    echo -e "-d DISTRIBUTION\t[Optional] Distribution, default is 'rpm'."
    echo -e "-a ARCHITECTURE\t[Optional] Architecture, default is 'x64'."
    echo -e "-C STORE\t[Optional] Use the build cache in STORE (file:///path or s3://bucket/prefix): restore the plugins and the core found there instead of building them. Off by default."
    echo -e "-P\t[Optional] With -C, also publish to STORE what this run built. Only for trusted builds."
    echo -e "-D\tDestroy the docker environment"
    echo -e "-h\tPrint help"
}

# ====
# Build cache (opt-in): see build-scripts/cache/README.md
#
# Runs on the host: the container never gets the store credentials. The keys and the
# restored entries are handed to the container in artifacts/cache/, and the container
# leaves there what it built, for publish_cache to upload.
# ====
CACHE_REPOS=(
    "wazuh-indexer-common-utils|COMMON_UTILS_BRANCH"
    "wazuh-indexer-alerting|ALERTING_BRANCH"
    "wazuh-indexer-security-analytics|SECURITY_ANALYTICS_BRANCH"
    "wazuh-indexer-notifications|NOTIFICATIONS_BRANCH"
    "wazuh-indexer-reporting|INDEXER_REPORTING_BRANCH"
    "wazuh-indexer-plugins|INDEXER_PLUGINS_BRANCH"
)

# Prints the commit a branch, tag or full commit SHA of a wazuh repository points to.
function resolve_commit() {
    local repo="$1" ref="$2" refs
    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
        echo "$ref"
        return
    fi
    refs=$(git ls-remote "https://github.com/wazuh/${repo}" "refs/heads/${ref}" "refs/tags/${ref}" "refs/tags/${ref}^{}")
    # A branch first, then the commit an annotated tag points to, then a lightweight tag.
    awk -v ref="$ref" '
        $2 == "refs/heads/" ref { head = $1 }
        $2 == "refs/tags/" ref "^{}" { peeled = $1 }
        $2 == "refs/tags/" ref { tag = $1 }
        END { print (head != "" ? head : (peeled != "" ? peeled : tag)) }
    ' <<<"$refs"
}

# Resolves the plugin refs to commits (the container then builds exactly those), writes
# the keys and restores the entries found in the store.
function prepare_cache() {
    local cache_dir="${REPO_PATH}/artifacts/cache"
    local entry repo var ref commit args=()
    declare -A commits=()

    for entry in "${CACHE_REPOS[@]}"; do
        IFS='|' read -r repo var <<<"$entry"
        ref="${!var}"
        commit=$(resolve_commit "$repo" "$ref" || true)
        if [ -z "$commit" ]; then
            echo "WARNING: cannot resolve ${repo} '${ref}' to a commit; building without the cache."
            return 1
        fi
        echo "Cache: ${repo} '${ref}' is ${commit}"
        printf -v "$var" '%s' "$commit"
        commits[$repo]="$commit"
        args+=(-p "${repo}=${commit}")
    done

    # Called from a condition, so errexit is off in here: every step checks its result.
    local plugin_keys core_key
    plugin_keys=$(bash build-scripts/cache/cache-key.sh plugins -v "$VERSION" -r "$REVISION" "${args[@]}") || return 1
    core_key=$(bash build-scripts/cache/cache-key.sh core -d "$DISTRIBUTION" -a "$ARCHITECTURE") || return 1
    mkdir -p "${cache_dir}/restore" "${cache_dir}/publish" || return 1
    while read -r repo key; do
        echo "$repo $key ${commits[$repo]}"
    done <<<"$plugin_keys" >"${cache_dir}/keys" || return 1
    echo "core-${DISTRIBUTION}-${ARCHITECTURE} ${core_key}" >>"${cache_dir}/keys" || return 1

    local name key rc
    while read -r name key _; do
        rc=0
        bash build-scripts/cache/store.sh get "$CACHE_STORE" "$name" "$key" "${cache_dir}/restore/${name}" || rc=$?
        case "$rc" in
        0) echo "Cache hit:  ${name} ${key}" ;;
        3) echo "Cache miss: ${name} ${key}" ;;
        *)
            # A store that cannot be read is a miss: the artifact is built.
            echo "Cache read failed, building: ${name} ${key}"
            rm -rf "${cache_dir}/restore/${name}"
            ;;
        esac
    done <"${cache_dir}/keys"

    # The container user (UID 1000) writes the entries it builds into publish/.
    chown -R 1000:1000 "$cache_dir" 2>/dev/null || true
}

# Publishes what the container built. A failure here never fails the package build.
function publish_cache() {
    local cache_dir="${REPO_PATH}/artifacts/cache" dir name key
    for dir in "${cache_dir}"/publish/*/; do
        [ -f "${dir}manifest.json" ] || continue
        name=$(basename "$dir")
        key=$(awk -v name="$name" '$1 == name { print $2 }' "${cache_dir}/keys")
        bash build-scripts/cache/store.sh put "$CACHE_STORE" "$name" "$key" "$dir" ||
            echo "WARNING: publishing ${name} ${key} failed; the package build is not affected."
    done
}

# ====
# Main function
# ====
function main() {
    check_project_root_folder $0
    compose_file="build-scripts/${current}/compose.yml"
    # Prefer the Docker Compose v2 plugin; fall back to standalone docker-compose
    # (v1) when the plugin isn't installed (e.g. runners without it).
    if docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose -f $compose_file"
    elif command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose -f $compose_file"
    else
        echo "Error: neither 'docker compose' nor 'docker-compose' is available." >&2
        exit 1
    fi
    REPO_PATH=$(pwd)
    VERSION="$(bash ${REPO_PATH}/build-scripts/product_version.sh)"

    parse_args "${@}"

    export REPO_PATH
    export VERSION
    export INDEXER_PLUGINS_BRANCH
    export INDEXER_REPORTING_BRANCH
    export SECURITY_ANALYTICS_BRANCH
    export NOTIFICATIONS_BRANCH
    export ALERTING_BRANCH
    export COMMON_UTILS_BRANCH
    export ENGINE_TARBALL
    export REVISION
    export IS_STAGE
    export DISTRIBUTION
    export ARCHITECTURE

    if [[ "$DESTROY" == true || "$DESTROY" == "1" ]]; then
        $compose_cmd down -v
        exit 0
    fi

    if [ -z "$ENGINE_TARBALL" ]; then
        echo "Error: -e ENGINE_TARBALL is required."
        usage
        exit 1
    fi

    # The container builds in cache mode when it finds artifacts/cache/keys, so a
    # previous run's cache state must never reach a run without -C.
    rm -rf "${REPO_PATH}/artifacts/cache"
    if [ -n "$CACHE_STORE" ] && ! prepare_cache; then
        rm -rf "${REPO_PATH}/artifacts/cache"
        CACHE_PUBLISH=false
    fi

    # Fail the job if the builder container exits non-zero.
    $compose_cmd up --build --abort-on-container-exit --exit-code-from wazuh-indexer-builder

    if [ "$CACHE_PUBLISH" = true ]; then
        publish_cache
    fi
    #$compose_cmd down -v
}

main "$@"
