#!/bin/bash

# =========================
# Repository Bumper Script
# =========================
# This script updates the VERSION.json file and the changelog section of the
# RPM spec file for a new version release, then (depending on flags)
# reinitializes CHANGELOG.md and pins workflow references to the right
# branch/tag.
#
# Usage: repository_bumper.sh --version VERSION --stage STAGE --date DATE [--tag] [--set-as-main]
#
# The changelog entry will be added to the %changelog section of the RPM spec file,
# and will be formatted as follows:
#   * [DATE] support <info@wazuh.com> - [VERSION]
#   - More info: https://documentation.wazuh.com/current/release-notes/release-[VERSION].html

set -euo pipefail

# ====
# Print usage instructions
# ====
function usage() {
    echo "Usage: $0 --version VERSION --stage STAGE --date DATE [--tag] [--set-as-main]"
    echo "  --version VERSION   The new version to set in VERSION.json (e.g., 4.5.0)"
    echo "  --stage STAGE       The new stage to set in VERSION.json (alpha0, beta1, rc1, stable...)"
    echo "  --date DATE         The date to set in the RPM changelog (e.g., '2025-04-13')"
    echo "  --tag               Pin workflow references using tag format (v{version}-{stage})"
    echo "                      instead of branch format ({version})"
    echo "  --set-as-main       Enable main branch mode: bump version values only, keep"
    echo "                      workflow references pointing to main"
    exit 1
}

# ====
# Initialize logging
# Globals:
#   LOG_FILE
# ====
function init_logging() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
    LOG_FILE="$script_dir/repository_bumper_${timestamp}.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    log "Logging initialized. Log file: $LOG_FILE"
}

# ====
# Log messages with timestamp
# Arguments:
#   $1 - Message to log
# ====
function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# ====
# Navigate to the root of the repository
# Searches for a folder named `.github` as a marker
# Exits if root is not found
# ====
function navigate_to_project_root() {
    local repo_root_marker=".github"
    local script_path
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    if [[ "$script_path" == "/" ]]; then
        log "Error: Unable to find the repository root."
        exit 1
    fi

    cd "$script_path"
    log "Moved to repository root: $script_path"
}

# ====
# Validate input parameters
# Arguments:
#   $1 - version
#   $2 - stage
#   $3 - date
# ====
function validate_inputs() {
    local version="$1"
    local stage="$2"
    local date="$3"

    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Error: Invalid version format '$version'."
        exit 1
    fi

    local normalized_stage
    normalized_stage=$(echo "$stage" | tr '[:upper:]' '[:lower:]')
    if ! [[ $normalized_stage =~ ^(alpha[0-9]*|beta[0-9]*|rc[0-9]*|stable)$ ]]; then
        log "Error: Invalid stage format '$stage'."
        exit 1
    fi

    if ! [[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log "Error: Invalid date format $date."
        exit 1
    fi
}

# ====
# Changes the date format to the format used in the changelog files
# ====
function normalize_date() {
    local input_date="$1"
    local normalized=""

    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        normalized=$(LC_TIME=en_US.UTF-8 date -d "$input_date" +"%a %b %d %Y")
    else
        # BSD date (macOS)
        normalized=$(LC_TIME=en_US.UTF-8 date -jf "%Y-%m-%d" "$input_date" +"%a %b %d %Y")
    fi

    echo "$normalized"
}

# ====
# Check if jq is installed
# ====
function check_jq_installed() {
    if ! command -v jq &>/dev/null; then
        log "Error: 'jq' is not installed. Please install it to use this script."
        exit 1
    fi
}

# ====
# Print the version currently set in VERSION.json
# ====
function current_version() {
    jq -r '.version' VERSION.json
}

# ====
# Update the VERSION.json file with the new version and stage
# Arguments:
#   $1 - version
#   $2 - stage
# ====
function update_version_file() {
    local version="$1"
    local stage="$2"
    local file="VERSION.json"

    if [[ ! -f "$file" ]]; then
        log "Error: $file not found in the current directory: $(pwd)"
        exit 1
    fi

    jq --arg v "$version" --arg s "$stage" \
        '.version = $v | .stage = $s' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log "Updated $file with version=$version and stage=$stage"
}

# ====
# Update the changelog section of the RPM spec file, if needed
# Arguments:
#   $1 - version
#   $2 - date
# ====
function update_rpm_changelog() {
    local version="$1"
    local date="$2"
    local spec_file="distribution/packages/src/rpm/wazuh-indexer.rpm.spec"
    local changelog_entry="* $date support <info@wazuh.com> - $version"

    if grep -q "^- More info: .*release-$version\.html" "$spec_file"; then
        # Update existing changelog date
        awk -v version="$version" -v new_date="$date" '
            BEGIN { updated = 0 }
            {
                if ($0 ~ "^- More info: .*release-"version"\\.html") {
                    prev = NR - 1
                    lines[prev] = "* " new_date " support <info@wazuh.com> - " version
                    lines[NR] = $0
                    updated = 1
                } else {
                    lines[NR] = $0
                }
            }
            END {
                for (i = 1; i <= NR; i++) print lines[i]
            }
        ' "$spec_file" >"${spec_file}.tmp" && mv "${spec_file}.tmp" "$spec_file"

        log "Updated existing changelog entry for version=$version with date=$date"
    else
        log "Inserting changelog entry for version=$version"
        # Transform semver version to hyphen separated string
        local version_hyphenated
        version_hyphenated=$(echo "$version" | tr '.' '-')
        awk -v line1="$changelog_entry" -v line2="- More info: https://documentation.wazuh.com/current/release-notes/release-$version_hyphenated.html" '
        BEGIN { inserted=0 }
        {
            print
            if (!inserted && /^%changelog/) {
                print line1
                print line2
                inserted=1
            }
        }
        ' "$spec_file" >"${spec_file}.tmp" && mv "${spec_file}.tmp" "$spec_file"

        log "Inserted new changelog entry for version=$version with date=$date"
    fi
}

# ====
# Update the branch resolver action's version->main mapping.
#
# The branch resolver (.github/actions/5_builderpackage_indexer_branch_resolver)
# maps the version that lives on `main` to the literal branch `main`, and every
# other version to its own same-named branch. That mapping is hardcoded, so when
# `main`'s version is bumped it must be updated in lockstep, otherwise the
# resolver keeps pointing the old version at `main` and the new one at a branch
# that does not exist yet. This is only relevant in main branch mode
# (--set-as-main); release branches map to themselves and need no change.
#
# Arguments:
#   $1 - version
# ====
function update_branch_resolver() {
    local version="$1"
    local resolver_file=".github/actions/5_builderpackage_indexer_branch_resolver/resolve_branches.sh"

    if [[ ! -f "$resolver_file" ]]; then
        log "Branch resolver not found at $resolver_file; skipping."
        return 0
    fi

    if ! grep -qE '\[ "\$version" == "[0-9]+\.[0-9]+\.[0-9]+" \] && echo "main"' "$resolver_file"; then
        log "Warning: could not locate version->main mapping in $resolver_file; leaving unchanged."
        return 0
    fi

    sed -E -i.bak \
        's/(\[ "\$version" == ")[0-9]+\.[0-9]+\.[0-9]+(" \] && echo "main")/\1'"$version"'\2/' \
        "$resolver_file"
    rm -f "${resolver_file}.bak"

    log "Updated branch resolver mapping to '$version' -> main in $resolver_file"
}

# ====
# Parse command-line arguments
# Globals:
#   arg_version, arg_stage, arg_date, arg_tag, arg_set_as_main
# ====
function parse_args() {
    declare -g arg_version=""
    declare -g arg_stage=""
    declare -g arg_date=""
    declare -g arg_tag=""
    declare -g arg_set_as_main=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                arg_version="$2"
                shift 2
                ;;
            --stage)
                arg_stage="$2"
                shift 2
                ;;
            --date)
                arg_date="$2"
                shift 2
                ;;
            --tag)
                arg_tag="yes"
                shift 1
                ;;
            --set-as-main)
                arg_set_as_main="yes"
                shift 1
                ;;
            *)
                log "Error: Unknown argument '$1'."
                usage
                ;;
        esac
    done

    if [[ -z "$arg_version" || -z "$arg_stage" || -z "$arg_date" ]]; then
        log "Error: --version, --stage and --date are all required."
        usage
    fi

    if [[ -n "$arg_tag" && -n "$arg_set_as_main" ]]; then
        log "Error: --set-as-main cannot be used with --tag. --set-as-main keeps workflow" \
             "references pointing to main; --tag exists to convert them to a tag reference," \
             "which is never done on main."
        exit 1
    fi
}

# ====
# Main logic
# ====
function main() {
    parse_args "$@"

    init_logging
    log "Starting update for VERSION.json with version=$arg_version, stage=$arg_stage"

    navigate_to_project_root
    check_jq_installed
    validate_inputs "$arg_version" "$arg_stage" "$arg_date"

    local old_version
    old_version="$(current_version)"

    local normalized_date
    normalized_date=$(normalize_date "$arg_date")

    update_version_file "$arg_version" "$arg_stage"
    update_rpm_changelog "$arg_version" "$normalized_date"

    if [[ "$arg_version" != "$old_version" ]]; then
        log "Version changed: $old_version -> $arg_version"
        bash "$(dirname "${BASH_SOURCE[0]}")/changelog_sync.sh" "$arg_version"
    else
        log "Version unchanged ($arg_version); stage-only bump."
    fi

    if [[ -n "$arg_set_as_main" ]]; then
        update_branch_resolver "$arg_version"
        log "Main branch mode enabled: workflow references left pointing to main."
    else
        local refs_args=("$arg_version" "$arg_stage")
        [[ -n "$arg_tag" ]] && refs_args+=("--tag")
        bash "$(dirname "${BASH_SOURCE[0]}")/workflow_refs_sync.sh" "${refs_args[@]}"
    fi

    log "Update complete."
}

main "$@"
