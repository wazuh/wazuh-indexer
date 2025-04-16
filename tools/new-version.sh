#!/bin/bash
set -euo pipefail

function usage() {
    echo "Usage: $0 <version> <stage> <prev_version>"
    echo "  version:        The new version to set"
    echo "  stage:          The new stage to set in VERSION.json"
    echo "  prev_version:   The previous version"
    exit 1
}

# Ensure that exactly three arguments are passed
if [ "$#" -ne 3 ]; then
    usage
fi

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is not installed. Please install it and re-run the script." >&2
    exit 1
fi

VERSION=$1
STAGE=$2
PREVIOUS_VERSION=$3

# Paths
DISTRIBUTION_FILE="distribution/packages/src/rpm/wazuh-indexer.rpm.spec"
CHANGELOG_FILE="CHANGELOG.md"
RELEASE_NOTES_FILE="release-notes/wazuh.release-notes-${VERSION}.md"
# Files to update
FILES_TO_UPDATE=(
    "$DISTRIBUTION_FILE"
    "$CHANGELOG_FILE"
    "$RELEASE_NOTES_FILE"
)
# Initialize logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
LOG_FILE="$SCRIPT_DIR/repository_bumper_${TIMESTAMP}.log"
# Templates
CHANGELOG_TEMPLATE_CONTENT=$(
    cat <<'EOF'
# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [<VERSION>]
### Added
- 

### Dependencies
-

### Changed
- 

### Deprecated
-

### Removed
- 

### Fixed
- 

### Security
- 

[Unreleased <VERSION>]: https://github.com/wazuh/wazuh-indexer/compare/<PREVIOUS_VERSION>...<VERSION>
EOF
)
RELEASE_NOTES_TEMPLATE_CONTENT=$(
    cat <<'EOF'
<DATE> Version <VERSION> Release Notes

## [<VERSION>]
### Added
-

### Dependencies
-

### Changed
-

### Deprecated
-

### Removed
-

### Fixed
-

### Security
-
EOF
)

# Functions

function validate_inputs() {
    normalized_stage=$(echo "$STAGE" | tr '[:upper:]' '[:lower:]')

    if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format." >&2
        exit 1
    fi
    if ! [[ $normalized_stage =~ ^(alpha[0-9]*|beta[0-9]*|rc[0-9]*|stable)$ ]]; then
        echo "Error: Invalid stage format." >&2
        exit 1
    fi
    if ! [[ $PREVIOUS_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid previous version format." >&2
        exit 1
    fi
}

function navigate_to_project_root() {
    repo_root_marker=".github"
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    if [[ "$script_path" == "/" ]]; then
        echo "Error: Unable to find the repository root."
        exit 1
    fi

    cd "$script_path"
}

function update_rpm_spec() {
    current_date=$(date +"%a %b %d %Y")
    entry_line1="* $current_date support <info@wazuh.com> - $VERSION"
    entry_line2="- More info: https://documentation.wazuh.com/current/release-notes/release-$VERSION.html"

    awk -v l1="$entry_line1" -v l2="$entry_line2" '
        BEGIN { inserted=0 }
        {
            print
            if (!inserted && /^%changelog/) {
                print l1
                print l2
                print ""
                inserted=1
            }
        }
    ' "$DISTRIBUTION_FILE" >"${DISTRIBUTION_FILE}.tmp"
    mv "${DISTRIBUTION_FILE}.tmp" "$DISTRIBUTION_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated $DISTRIBUTION_FILE with changelog for version=$VERSION"
}

function update_changelog() {
    content=$(echo "$CHANGELOG_TEMPLATE_CONTENT" | sed "s|<VERSION>|$VERSION|g" | sed "s|<PREVIOUS_VERSION>|$PREVIOUS_VERSION|g")
    echo "$content" >"$CHANGELOG_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated $CHANGELOG_FILE with version=$VERSION"
}

function update_release_notes() {
    today=$(date +%Y-%m-%d)
    content=$(echo "$RELEASE_NOTES_TEMPLATE_CONTENT" | sed "s|<VERSION>|$VERSION|g" | sed "s|<DATE>|$today|g")
    echo "$content" >"$RELEASE_NOTES_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Created $RELEASE_NOTES_FILE with version=$VERSION"
}

# Init process.
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting initialization for version=$VERSION, stage=$STAGE, prev_version=$PREVIOUS_VERSION"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Log file: $LOG_FILE"

navigate_to_project_root
validate_inputs
update_rpm_spec
update_changelog
update_release_notes

echo "[$(date +"%Y-%m-%d %H:%M:%S")] All updates completed successfully."
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Affected files:"
for file in "${FILES_TO_UPDATE[@]}"; do
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] - $file"
done
