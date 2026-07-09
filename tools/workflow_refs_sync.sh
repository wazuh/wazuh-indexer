#!/bin/bash

# =========================
# Workflow References Sync
# =========================
# Pins "uses: wazuh/<repo>/...@<ref>" reusable workflow/action references in
# .github/workflows/*.yml to the current release. Matches both a still-
# unpinned "@main" reference and any reference this script pinned on a
# previous bump (branch-style or tag-style), so every bump converges
# references to the current state regardless of what was there before.
#
# Called by repository_bumper.sh on every bump except when --set-as-main is
# used (main's references to other repos' main are already correct).
#
# Does not verify that the referenced repo actually has that branch/tag —
# it rewrites unconditionally, trusting the caller.
#
# Arguments:
# 1. version (e.g. 5.1.0)
# 2. stage (e.g. beta1)
# Flags:
#   --tag   Pin using tag format (v{version}-{stage}) instead of branch
#           format ({version})

set -euo pipefail

REF_PATTERN='(main|v?[0-9]+\.[0-9]+\.[0-9]+(-[[:alnum:]]+)?)'

function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

function find_referenced_repos() {
    local matches
    matches=$(grep -rhoE "uses:[[:space:]]*wazuh/[^/[:space:]]+/[^[:space:]]*@${REF_PATTERN}" .github/workflows/*.yml 2>/dev/null || true)

    [[ -z "$matches" ]] && return 0

    printf '%s\n' "$matches" | sed -E 's#.*wazuh/([^/]+)/.*#\1#' | sort -u
}

function pin_repo_references() {
    local repo="$1"
    local bump_string="$2"
    local escaped_bump_string
    escaped_bump_string=$(printf '%s' "$bump_string" | sed -e 's/[\\&#]/\\&/g')

    local f
    for f in .github/workflows/*.yml; do
        [[ -f "$f" ]] || continue
        if grep -qE "uses:[[:space:]]*wazuh/${repo}/.*@${REF_PATTERN}" "$f"; then
            sed -i -E "s#(uses:[[:space:]]*wazuh/${repo}/[^[:space:]]+)@${REF_PATTERN}#\1@${escaped_bump_string}#" "$f"
            log "Pinned wazuh/$repo references to '$bump_string' in $f"
        fi
    done
}

function main() {
    if [[ $# -lt 2 ]]; then
        log "Usage: $0 <version> <stage> [--tag]"
        exit 1
    fi

    local version="$1"
    local stage="$2"
    shift 2

    local tag=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag)
                tag="yes"
                shift 1
                ;;
            *)
                log "Error: Unknown argument '$1'."
                exit 1
                ;;
        esac
    done

    local bump_string
    if [[ -n "$tag" ]]; then
        bump_string="v${version}-${stage}"
    else
        bump_string="${version}"
    fi

    local repo
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        pin_repo_references "$repo" "$bump_string"
    done < <(find_referenced_repos)
}

main "$@"
