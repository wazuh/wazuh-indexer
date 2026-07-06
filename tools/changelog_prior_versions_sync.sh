#!/bin/bash

# =========================
# Changelog Prior Versions Sync
# =========================
# Walks backwards from the given version looking for release branches that
# exist on the remote but are missing from CHANGELOG.md's "## Prior versions"
# section, and adds them. Called by repository_bumper.sh after every bump.
#
# Within the current (still open) minor, every earlier existing patch is
# included. For each earlier, already-closed minor, only its ".0" baseline
# plus the two highest existing patches above it are included.
#
# Arguments:
# 1. The version just bumped to (e.g., 5.1.1)

set -euo pipefail

function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# ====
# Determine the "org/repo" path from the origin remote URL.
# ====
function get_repo_path() {
    local remote_url
    remote_url=$(git remote get-url origin)
    remote_url="${remote_url%.git}"
    remote_url="${remote_url#*github.com/}"
    remote_url="${remote_url#*github.com:}"
    echo "$remote_url"
}

# ====
# Check whether a branch named "X.Y.Z" or "vX.Y.Z" exists on the remote.
# Arguments:
#   $1 - version (e.g. 5.0.1)
# ====
function remote_branch_exists() {
    local version="$1"
    git ls-remote --exit-code --heads origin "$version" &>/dev/null ||
        git ls-remote --exit-code --heads origin "v$version" &>/dev/null
}

# ====
# Add a version entry to CHANGELOG.md's "## Prior versions" section, if not
# already present. Each call inserts right below the heading, so callers
# must call this oldest-version-first for the final list to read newest-first.
# Arguments:
#   $1 - version to record
# ====
function add_prior_version_entry() {
    local version="$1"
    local file="CHANGELOG.md"
    local repo_path
    repo_path=$(get_repo_path)
    local entry="- [${version}](https://github.com/${repo_path}/blob/${version}/CHANGELOG.md)"

    if [[ ! -f "$file" ]]; then
        log "Warning: $file not found; skipping Prior versions update."
        return 0
    fi

    if grep -qF -- "$entry" "$file"; then
        return 0
    fi

    if grep -qE "^## Prior versions?$" "$file"; then
        # Matches singular or plural heading; replaces the "- []()" placeholder if present.
        awk -v entry="$entry" '
            /^## Prior versions?$/ && !done {
                print "## Prior versions"
                print entry
                done = 1
                skip_placeholder = 1
                next
            }
            skip_placeholder {
                skip_placeholder = 0
                if ($0 == "- []()") next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        {
            echo ""
            echo "## Prior versions"
            echo "$entry"
        } >> "$file"
    fi

    log "Added $version to Prior versions in $file"
}

# ====
# Every existing patch below the given one, within the same (still open)
# minor. Emitted oldest first.
# Arguments:
#   $1 - major, $2 - minor, $3 - patch (exclusive upper bound)
# ====
function current_minor_candidates() {
    local major="$1" minor="$2" patch="$3"
    local p candidate
    for ((p = 0; p < patch; p++)); do
        candidate="${major}.${minor}.${p}"
        if remote_branch_exists "$candidate"; then
            echo "$candidate"
        fi
    done
}

# ====
# For an already-closed minor: its ".0" baseline (if it exists), plus the two
# highest existing patches above it. Emitted oldest first (baseline, then the
# kept patches in ascending order).
# Arguments:
#   $1 - major, $2 - minor
# ====
function closed_minor_candidates() {
    local major="$1" minor="$2"
    local baseline="${major}.${minor}.0"

    local p candidate
    local -a found=()
    for ((p = 1; p <= 9; p++)); do
        candidate="${major}.${minor}.${p}"
        if remote_branch_exists "$candidate"; then
            found+=("$candidate")
        fi
    done

    if remote_branch_exists "$baseline"; then
        echo "$baseline"
    fi

    local count=${#found[@]}
    local start=0
    if ((count > 2)); then
        start=$((count - 2))
    fi

    local i
    for ((i = start; i < count; i++)); do
        echo "${found[$i]}"
    done
}

# ====
# Build the full list of candidate versions to add, oldest first (see
# add_prior_version_entry for why the order matters).
# Arguments:
#   $1 - version (e.g. 5.1.1)
# ====
function build_candidates() {
    local version="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    local y
    for ((y = 0; y <= minor - 1; y++)); do
        closed_minor_candidates "$major" "$y"
    done

    current_minor_candidates "$major" "$minor" "$patch"
}

# ====
# Main logic
# ====
function main() {
    if [[ $# -ne 1 ]]; then
        log "Usage: $0 <version>"
        exit 1
    fi

    local version="$1"

    while IFS= read -r candidate; do
        add_prior_version_entry "$candidate"
    done < <(build_candidates "$version")
}

main "$@"
