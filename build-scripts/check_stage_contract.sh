#!/bin/bash

# Checks the stage contract: the files that the build stage of the builder
# leaves behind and the package stage consumes (wazuh/wazuh-indexer#2130).
#
#   artifacts/plugins/<artifact>-<VERSION>.<REVISION>.zip    7 Wazuh plugins
#   artifacts/core/wazuh-indexer-min*<suffix>*.<ext>          core distribution (Gradle name)
#   plugins/<internal plugin>/build/distributions/<internal plugin>-<OpenSearch version>.zip
#   artifacts/commits.txt                                     commit of each repository
#
# It is used by the package stage of the builder (inside the container) and by
# build-scripts/ci/stage_contract.sh (on the CI host), so both apply the same rules.
# Every problem found is reported before exiting with an error.

set -euo pipefail

# Keep in sync with copy_builds in build-scripts/builder/entrypoint.sh.
WAZUH_PLUGINS=(
    "wazuh-indexer-setup"
    "wazuh-indexer-content-manager"
    "wazuh-indexer-reports-scheduler"
    "wazuh-indexer-security-analytics"
    "wazuh-indexer-notifications-core"
    "wazuh-indexer-notifications"
    "wazuh-indexer-alerting"
)

# Keep in sync with internal_plugins in build-scripts/assemble.sh.
INTERNAL_PLUGINS=(
    "workload-management"
)

# Repositories recorded in artifacts/commits.txt, in build order.
COMMIT_REPOS=(
    "wazuh-indexer-common-utils"
    "wazuh-indexer-alerting"
    "wazuh-indexer-security-analytics"
    "wazuh-indexer-notifications"
    "wazuh-indexer-reporting"
    "wazuh-indexer-plugins"
    "wazuh-indexer"
)

function usage() {
    echo "Usage: $0 -d DISTRIBUTION -a ARCHITECTURE -r REVISION -v VERSION [-w WORKSPACE] [-l]"
    echo ""
    echo "Arguments:"
    echo -e "-d DISTRIBUTION\t[Required] Distribution: tar, deb or rpm."
    echo -e "-a ARCHITECTURE\t[Required] Architecture: x64 or arm64."
    echo -e "-r REVISION\t[Required] Package revision used by the build stage."
    echo -e "-v VERSION\t[Required] Product version (VERSION.json)."
    echo -e "-w WORKSPACE\t[Optional] Root of the repository, default is the current directory."
    echo -e "-l\t\t[Optional] On success, print the contract paths relative to WORKSPACE, one per line."
    echo -e "-h\t\tPrint help"
}

function parse_args() {
    DISTRIBUTION=""
    ARCHITECTURE=""
    REVISION=""
    VERSION=""
    WORKSPACE="."
    LIST=false

    while getopts ":d:a:r:v:w:lh" arg; do
        case $arg in
        d) DISTRIBUTION=$OPTARG ;;
        a) ARCHITECTURE=$OPTARG ;;
        r) REVISION=$OPTARG ;;
        v) VERSION=$OPTARG ;;
        w) WORKSPACE=$OPTARG ;;
        l) LIST=true ;;
        h)
            usage
            exit 0
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument" >&2
            usage >&2
            exit 1
            ;;
        ?)
            echo "Invalid option: -${OPTARG}" >&2
            exit 1
            ;;
        esac
    done

    if [ -z "$DISTRIBUTION" ] || [ -z "$ARCHITECTURE" ] || [ -z "$REVISION" ] || [ -z "$VERSION" ]; then
        echo "Error: -d, -a, -r and -v are required." >&2
        usage >&2
        exit 1
    fi

    # Same suffixes and extensions as build.sh and assemble.sh use for Linux.
    case "$DISTRIBUTION-$ARCHITECTURE" in
    tar-x64)   SUFFIX="linux-x64";   EXT="tar.gz" ;;
    tar-arm64) SUFFIX="linux-arm64"; EXT="tar.gz" ;;
    deb-x64)   SUFFIX="amd64";       EXT="deb" ;;
    deb-arm64) SUFFIX="arm64";       EXT="deb" ;;
    rpm-x64)   SUFFIX="x86_64";      EXT="rpm" ;;
    rpm-arm64) SUFFIX="aarch64";     EXT="rpm" ;;
    *)
        echo "Error: unsupported distribution-architecture combination: $DISTRIBUTION-$ARCHITECTURE" >&2
        exit 1
        ;;
    esac
}

PROBLEMS=()
PATHS=()

function check_plugins() {
    local artifact path
    for artifact in "${WAZUH_PLUGINS[@]}"; do
        path="artifacts/plugins/${artifact}-${VERSION}.${REVISION}.zip"
        if [ -f "${WORKSPACE}/${path}" ]; then
            PATHS+=("$path")
        else
            PROBLEMS+=("missing plugin zip: ${path}")
        fi
    done
}

function check_core() {
    local candidates=()
    local file
    shopt -s nullglob
    for file in "${WORKSPACE}"/artifacts/core/*; do
        candidates+=("$(basename "$file")")
    done
    shopt -u nullglob

    if [ "${#candidates[@]}" -ne 1 ]; then
        PROBLEMS+=("expected exactly one core distribution in artifacts/core, found ${#candidates[@]}: ${candidates[*]:-none}")
        return
    fi
    # Same pattern assemble.sh uses to find the min package.
    if ! grep -Eq "^wazuh-indexer-min.*${SUFFIX}.*\.${EXT}$" <<<"${candidates[0]}"; then
        PROBLEMS+=("core distribution does not match ${DISTRIBUTION}-${ARCHITECTURE}: artifacts/core/${candidates[0]}")
        return
    fi
    PATHS+=("artifacts/core/${candidates[0]}")
}

function check_internal_plugins() {
    local opensearch_version plugin path
    opensearch_version=$(cd "$WORKSPACE" && bash build-scripts/opensearch_version.sh)
    for plugin in "${INTERNAL_PLUGINS[@]}"; do
        path="plugins/${plugin}/build/distributions/${plugin}-${opensearch_version}.zip"
        if [ -f "${WORKSPACE}/${path}" ]; then
            PATHS+=("$path")
        else
            PROBLEMS+=("missing internal plugin zip: ${path}")
        fi
    done
}

function check_commits_file() {
    local path="artifacts/commits.txt"
    local file="${WORKSPACE}/${path}"
    if [ ! -f "$file" ]; then
        PROBLEMS+=("missing ${path}")
        return
    fi

    local -A seen=()
    local repo full short extra known r line_number=0 ok=true
    while read -r repo full short extra || [ -n "${repo:-}" ]; do
        line_number=$((line_number + 1))
        if [ -z "${repo:-}" ] || [[ "$repo" == \#* ]]; then
            continue
        fi
        if [ -n "${extra:-}" ] || [ -z "${short:-}" ]; then
            PROBLEMS+=("${path}:${line_number}: expected '<repo> <full sha> <short sha>'")
            ok=false
            continue
        fi
        known=false
        for r in "${COMMIT_REPOS[@]}"; do
            if [ "$r" == "$repo" ]; then
                known=true
            fi
        done
        if [ "$known" == false ]; then
            PROBLEMS+=("${path}:${line_number}: unexpected repository '${repo}'")
            ok=false
            continue
        fi
        if ! [[ "$full" =~ ^[0-9a-f]{40}$ ]] || ! [[ "$short" =~ ^[0-9a-f]{4,40}$ ]] || [[ "$full" != "$short"* ]]; then
            PROBLEMS+=("${path}:${line_number}: invalid commit for ${repo}")
            ok=false
            continue
        fi
        seen[$repo]=$((${seen[$repo]:-0} + 1))
    done <"$file"

    for r in "${COMMIT_REPOS[@]}"; do
        if [ "${seen[$r]:-0}" -ne 1 ]; then
            PROBLEMS+=("${path}: ${r} must appear exactly once, found ${seen[$r]:-0}")
            ok=false
        fi
    done

    if [ "$ok" == true ]; then
        PATHS+=("$path")
    fi
}

function main() {
    parse_args "$@"

    check_plugins
    check_core
    check_internal_plugins
    check_commits_file

    if [ "${#PROBLEMS[@]}" -gt 0 ]; then
        echo "Error: the stage contract for ${DISTRIBUTION}-${ARCHITECTURE} is incomplete:" >&2
        printf '  - %s\n' "${PROBLEMS[@]}" >&2
        exit 1
    fi

    if [ "$LIST" == true ]; then
        printf '%s\n' "${PATHS[@]}"
    else
        echo "Stage contract for ${DISTRIBUTION}-${ARCHITECTURE} is complete (${#PATHS[@]} files)." >&2
    fi
}

main "$@"
