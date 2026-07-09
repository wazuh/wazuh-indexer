#!/bin/bash

# =========================
# Changelog Sync
# =========================
# Reinitializes CHANGELOG.md to the standard empty template for the given
# version, with a freshly computed "Prior versions" section. Called by
# repository_bumper.sh only when the version number actually changes (never
# on a stage-only bump).
#
# Prior versions are discovered from git tags (not branches): the two most
# recent minor versions below the one just bumped, listing every stable
# patch tag found for each of them. If the repo has no stable tags yet,
# the "## Prior versions" section is written with no entries under it.
#
# Arguments:
# 1. The version just bumped to (e.g., 5.1.0)

set -euo pipefail

function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

function get_repo_path() {
    local remote_url
    remote_url=$(git remote get-url origin)
    remote_url="${remote_url%.git}"
    remote_url="${remote_url#*github.com/}"
    remote_url="${remote_url#*github.com:}"
    echo "$remote_url"
}

function fetch_stable_tags() {
    git ls-remote --tags origin | sed -E 's#^[0-9a-f]+[[:space:]]+refs/tags/##' \
        | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' || true
}

function build_prior_versions() {
    local version="$1"
    local major="${version%%.*}"
    local target_rest="${version#*.}"
    local target_minor="${target_rest%%.*}"

    local tags
    tags="$(fetch_stable_tags)"
    [[ -z "$tags" ]] && return 0

    local name stripped t_major rest t_minor t_patch
    local grouped=""
    while IFS= read -r name; do
        stripped="${name#v}"
        t_major="${stripped%%.*}"
        [[ "$t_major" != "$major" ]] && continue
        rest="${stripped#*.}"
        t_minor="${rest%%.*}"
        [[ "$t_minor" == "$target_minor" ]] && continue
        t_patch="${rest#*.}"
        grouped+="${t_minor}\t${t_patch}\t${name}\n"
    done <<< "$tags"

    [[ -z "$grouped" ]] && return 0

    local minor
    for minor in $(printf '%b' "$grouped" | cut -f1 | sort -run | head -2); do
        printf '%b' "$grouped" | awk -F'\t' -v m="$minor" '$1 == m' | sort -t$'\t' -k2 -rn | cut -f3
    done
}

function render_changelog() {
    local version="$1"
    local repo_path
    repo_path="$(get_repo_path)"

    {
        echo "## [v${version}]"
        echo ""
        echo "### Added"
        echo ""
        echo "### Changed"
        echo ""
        echo "### Removed"
        echo ""
        echo "### Fixed"
        echo ""
        echo "## Prior versions"

        local prior
        prior="$(build_prior_versions "$version")"
        if [[ -n "$prior" ]]; then
            while IFS= read -r name; do
                echo "- [${name}](https://github.com/${repo_path}/blob/${name}/CHANGELOG.md)"
            done <<< "$prior"
        fi
    } > CHANGELOG.md

    log "Reinitialized CHANGELOG.md for v${version}"
}

function main() {
    if [[ $# -ne 1 ]]; then
        log "Usage: $0 <version>"
        exit 1
    fi

    render_changelog "$1"
}

main "$@"
