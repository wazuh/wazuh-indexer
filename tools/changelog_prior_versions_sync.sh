#!/bin/bash

# =========================
# Changelog Prior Versions Sync
# =========================
# Fetches every branch on the remote once, then adds to CHANGELOG.md's
# "## Prior versions" section any version (within the same major as the one
# just bumped to) that is missing from it. Called by repository_bumper.sh
# after every bump.
#
# For every minor found (the one just bumped into included), only its ".0"
# baseline (if it exists) plus the two highest existing patches above it are
# added.
#
# Arguments:
# 1. The version just bumped to (e.g., 5.1.1)

set -euo pipefail

function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# ====
# Determine the repo path from the origin remote URL.
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
# Fetch every branch on the remote once, keep only version-shaped names
# ("X.Y.Z" or "vX.Y.Z") belonging to the given major, excluding the version
# just bumped to. Emits "minor<TAB>patch<TAB>name" lines, any order.
# Arguments:
#   $1 - major
#   $2 - version just bumped to, to exclude (e.g. 5.1.1)
# ====
function fetch_major_branches() {
    local major="$1"
    local exclude="$2"

    local all_branches
    all_branches=$(git ls-remote --heads origin | sed -E 's#^[0-9a-f]+[[:space:]]+refs/heads/##')

    local versioned
    versioned=$(printf '%s\n' "$all_branches" | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+$" || true)

    [[ -z "$versioned" ]] && return 0

    local name stripped b_major rest b_minor b_patch
    while IFS= read -r name; do
        stripped="${name#v}"
        b_major="${stripped%%.*}"
        [[ "$b_major" != "$major" ]] && continue
        [[ "$stripped" == "$exclude" ]] && continue
        rest="${stripped#*.}"
        b_minor="${rest%%.*}"
        b_patch="${rest#*.}"
        printf '%s\t%s\t%s\n' "$b_minor" "$b_patch" "$name"
    done <<< "$versioned"
}

# ====
# Given "minor<TAB>patch<TAB>name" lines for a SINGLE minor on stdin, emit
# its ".0" baseline (if present) plus its two highest non-baseline patches.
# Emitted oldest first.
# ====
function minor_entries() {
    local baseline=""
    local -a others=()
    local _ patch name

    while IFS=$'\t' read -r _ patch name; do
        if [[ "$patch" == "0" ]]; then
            baseline="$name"
        else
            others+=("$patch $name")
        fi
    done

    if [[ -n "$baseline" ]]; then
        echo "$baseline"
    fi

    if ((${#others[@]} > 0)); then
        printf '%s\n' "${others[@]}" | sort -rn | head -2 | sort -n | while IFS=' ' read -r _ name; do
            echo "$name"
        done
    fi
}

# ====
# Build the full list of candidate versions to add, oldest first (see
# add_prior_version_entry for why the order matters).
# Arguments:
#   $1 - version (e.g. 5.1.1)
# ====
function build_candidates() {
    local version="$1"
    local major="${version%%.*}"

    local branches
    branches=$(fetch_major_branches "$major" "$version")

    [[ -z "$branches" ]] && return 0

    local minor
    for minor in $(printf '%s\n' "$branches" | cut -f1 | sort -un); do
        printf '%s\n' "$branches" | awk -F'\t' -v m="$minor" '$1 == m' | minor_entries
    done
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
