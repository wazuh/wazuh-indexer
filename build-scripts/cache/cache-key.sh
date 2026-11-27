#!/bin/bash

# Computes the cache keys of the package build dependencies.
#
#   cache-key.sh core -d DISTRIBUTION -a ARCHITECTURE [-c COMMIT] [-x]
#   cache-key.sh plugins -v VERSION -r REVISION -p REPO=COMMIT... [-x]
#
# A key is the SHA-256 of a short text that lists every input deciding the artifact,
# and nothing else. -x prints that text (to stderr) next to the key, to see why two
# keys differ. The rules are documented in build-scripts/cache/README.md.

set -euo pipefail

CACHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${CACHE_DIR}/../.." && pwd)"
EPOCH="$(tr -d '[:space:]' <"${CACHE_DIR}/epoch")"

# The plugin repositories in build order, and the ones each compiles against. A key
# includes the keys of its dependencies, so a change propagates to every dependent.
PLUGIN_REPOS=(
    wazuh-indexer-common-utils
    wazuh-indexer-alerting
    wazuh-indexer-security-analytics
    wazuh-indexer-notifications
    wazuh-indexer-reporting
    wazuh-indexer-plugins
)
declare -A PLUGIN_DEPS=(
    [wazuh-indexer-common-utils]=""
    [wazuh-indexer-alerting]="wazuh-indexer-common-utils"
    [wazuh-indexer-security-analytics]="wazuh-indexer-common-utils wazuh-indexer-alerting"
    [wazuh-indexer-notifications]="wazuh-indexer-common-utils"
    [wazuh-indexer-reporting]="wazuh-indexer-common-utils"
    [wazuh-indexer-plugins]="wazuh-indexer-security-analytics"
)

EXPLAIN=false

function usage() {
    echo "Usage:"
    echo "  $0 core -d DISTRIBUTION -a ARCHITECTURE [-c COMMIT] [-x]"
    echo "  $0 plugins -v VERSION -r REVISION -p REPO=COMMIT... [-x]"
    echo ""
    echo "core     Key of the OpenSearch core (min package) of one distribution and architecture."
    echo "         Computed from the working tree (committed or not, untracked files included,"
    echo "         ignored files left out), or from COMMIT when -c is given."
    echo "plugins  Keys of the plugin repositories, one '<repo> <key>' line each, in build order."
    echo "         Every repository in PLUGIN_REPOS needs a -p REPO=COMMIT with a full commit SHA."
    echo "-x       Print the key inputs to stderr."
}

# Hashes the key text and prints the key; with -x, prints the text as well.
function emit_key() {
    local text="$1"
    if [ "${EXPLAIN}" = true ]; then
        printf '%s\n' "${text}" | sed 's/^/  | /' >&2
    fi
    printf '%s\n' "${text}" | sha256sum | cut -d' ' -f1
}

# Prints the non-comment, non-empty lines of a list file.
function read_list() {
    grep -vE '^[[:space:]]*(#|$)' "$1" || true
}

# Prints "<mode> <blob> <stage>\t<path>" for every file of the core key, sorted by path.
function core_tree_listing() {
    local commit="$1"
    local tmp
    tmp="$(mktemp -d)"
    # A private index, so the real one is never touched.
    export GIT_INDEX_FILE="${tmp}/index"

    if [ -n "${commit}" ]; then
        git -C "${REPO_ROOT}" read-tree "${commit}"
    else
        git -C "${REPO_ROOT}" read-tree HEAD
        # Stage the working tree, untracked files included, so local changes count.
        git -C "${REPO_ROOT}" add -A -- .
    fi

    local excludes=() includes=() line
    while IFS= read -r line; do
        excludes+=(":(exclude,glob)${line}")
    done < <(read_list "${CACHE_DIR}/core.exclude")
    while IFS= read -r line; do
        includes+=(":(literal)${line}")
    done < <(read_list "${CACHE_DIR}/core.include")

    {
        git -C "${REPO_ROOT}" ls-files -s -- . "${excludes[@]}"
        git -C "${REPO_ROOT}" ls-files -s -- "${includes[@]}"
    } | LC_ALL=C sort -t$'\t' -k2 -u

    unset GIT_INDEX_FILE
    rm -rf "${tmp}"
}

function core_key() {
    local distribution="" architecture="" commit="" arg
    OPTIND=1
    while getopts ":d:a:c:x" arg; do
        case "${arg}" in
        d) distribution="${OPTARG}" ;;
        a) architecture="${OPTARG}" ;;
        c) commit="${OPTARG}" ;;
        x) EXPLAIN=true ;;
        *) usage >&2; exit 1 ;;
        esac
    done
    if [ -z "${distribution}" ] || [ -z "${architecture}" ]; then
        usage >&2
        exit 1
    fi

    local version_json
    if [ -n "${commit}" ]; then
        commit="$(git -C "${REPO_ROOT}" rev-parse --verify "${commit}^{commit}")"
        version_json="$(git -C "${REPO_ROOT}" show "${commit}:VERSION.json")"
    else
        version_json="$(cat "${REPO_ROOT}/VERSION.json")"
    fi

    local tree_hash
    tree_hash="$(core_tree_listing "${commit}" | sha256sum | cut -d' ' -f1)"
    if [ "${EXPLAIN}" = true ]; then
        echo "Core key files: $(core_tree_listing "${commit}" | wc -l)" >&2
    fi

    emit_key "wazuh-indexer cache key
epoch=${EPOCH}
artifact=core
distribution=${distribution}
architecture=${architecture}
product_version=$(jq -r .version <<<"${version_json}")
tree=${tree_hash}"
}

function plugin_keys() {
    local version="" revision="" arg repo commit
    declare -A commits=()
    OPTIND=1
    while getopts ":v:r:p:x" arg; do
        case "${arg}" in
        v) version="${OPTARG}" ;;
        r) revision="${OPTARG}" ;;
        p)
            repo="${OPTARG%%=*}"
            commit="${OPTARG#*=}"
            if [ -z "${PLUGIN_DEPS[${repo}]+set}" ]; then
                echo "Unknown plugin repository: ${repo}" >&2
                exit 1
            fi
            commits[${repo}]="${commit}"
            ;;
        x) EXPLAIN=true ;;
        *) usage >&2; exit 1 ;;
        esac
    done
    if [ -z "${version}" ] || [ -z "${revision}" ]; then
        usage >&2
        exit 1
    fi

    # The builder runs the plugin builds from entrypoint.sh, so a change in how it calls
    # Gradle (flags, tasks, order) has to invalidate them.
    local builder_hash
    builder_hash="$(sha256sum "${REPO_ROOT}/build-scripts/builder/entrypoint.sh" | cut -d' ' -f1)"

    declare -A keys=()
    local text dep
    for repo in "${PLUGIN_REPOS[@]}"; do
        commit="${commits[${repo}]:-}"
        # A branch or tag name would make the key move with the branch: only full SHAs.
        if ! [[ "${commit}" =~ ^[0-9a-f]{40}$ ]]; then
            echo "Missing or not a full commit SHA for ${repo}: '${commit}'" >&2
            exit 1
        fi
        text="wazuh-indexer cache key
epoch=${EPOCH}
artifact=plugin/${repo}
commit=${commit}
product_version=${version}
revision=${revision}
builder=${builder_hash}"
        for dep in ${PLUGIN_DEPS[${repo}]}; do
            text+=$'\n'"dependency/${dep}=${keys[${dep}]}"
        done
        if [ "${EXPLAIN}" = true ]; then
            echo "${repo}:" >&2
        fi
        keys[${repo}]="$(emit_key "${text}")"
        echo "${repo} ${keys[${repo}]}"
    done
}

function main() {
    local command="${1:-}"
    shift || true
    case "${command}" in
    core) core_key "$@" ;;
    plugins) plugin_keys "$@" ;;
    -h | --help) usage ;;
    *) usage >&2; exit 1 ;;
    esac
}

main "$@"
