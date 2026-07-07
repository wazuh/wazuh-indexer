#!/bin/bash

# =========================
# Workflow References Sync
# =========================
# On any branch other than main, finds "uses: wazuh/<repo>/...@main" reusable
# workflow/action references in .github/workflows/*.yml and pins them to the
# current branch, for every referenced repo that actually has a branch with
# that name. Called by repository_bumper.sh after every bump.
#
# On main, does nothing , main's references to other repos' main are correct
# as they are.

set -euo pipefail

function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# ====
# Determine the branch this script is running on. In GitHub Actions,
# actions/checkout leaves the repo in a detached HEAD state, so
# `git rev-parse --abbrev-ref HEAD` would return the literal string "HEAD"
# instead of the branch name. GITHUB_REF_NAME is set automatically by the
# Actions runner and is used first; git is only a fallback for local runs.
# ====
function get_current_branch() {
    if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        echo "$GITHUB_REF_NAME"
    else
        git rev-parse --abbrev-ref HEAD
    fi
}

# ====
# Check whether the given wazuh/<repo> has a branch with the given name.
# Arguments:
#   $1 - repo (e.g. wazuh-indexer)
#   $2 - branch
# ====
function remote_branch_exists() {
    local repo="$1"
    local branch="$2"
    git ls-remote --exit-code --heads "https://github.com/wazuh/${repo}.git" "$branch" &>/dev/null
}

# ====
# Every distinct repo referenced as "wazuh/<repo>/...@main" across
# .github/workflows/*.yml.
# ====
function find_referenced_repos() {
    local matches
    matches=$(grep -rhoE 'uses:[[:space:]]*wazuh/[^/[:space:]]+/[^[:space:]]*@main' .github/workflows/*.yml 2>/dev/null || true)

    [[ -z "$matches" ]] && return 0

    printf '%s\n' "$matches" | sed -E 's#.*wazuh/([^/]+)/.*#\1#' | sort -u
}

# ====
# Replace "@main" with "@<branch>" in every "wazuh/<repo>/...@main" reference
# across .github/workflows/*.yml.
# Arguments:
#   $1 - repo (e.g. wazuh-indexer)
#   $2 - branch to pin to
# ====
function pin_repo_references() {
    local repo="$1"
    local branch="$2"
    local escaped_branch
    escaped_branch=$(printf '%s' "$branch" | sed -e 's/[\\&#]/\\&/g')

    local f
    for f in .github/workflows/*.yml; do
        [[ -f "$f" ]] || continue
        if grep -qE "uses:[[:space:]]*wazuh/${repo}/.*@main" "$f"; then
            sed -i -E "s#(uses:[[:space:]]*wazuh/${repo}/[^[:space:]]+)@main#\1@${escaped_branch}#" "$f"
            log "Pinned wazuh/$repo references to '$branch' in $f"
        fi
    done
}

# ====
# Main logic
# ====
function main() {
    local branch
    branch="$(get_current_branch)"

    if [[ "$branch" == "main" ]]; then
        log "Running on main; leaving @main references to other repos untouched."
        return 0
    fi

    local repo
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        if remote_branch_exists "$repo" "$branch"; then
            pin_repo_references "$repo" "$branch"
        else
            log "No branch '$branch' in wazuh/$repo; leaving its @main references untouched."
        fi
    done < <(find_referenced_repos)
}

main "$@"
