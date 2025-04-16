#!/bin/bash
set -euo pipefail

# -------------------------------
# Wazuh Indexer New Version Initialization Process
# -------------------------------
# This script updates:
# - VERSION.json: sets new "version" and "stage"
# - RPM spec file: inserts a new changelog entry after "%changelog"
# - CHANGELOG.md: updates the VERSION section using a template
# - Release notes file: create/update release-notes for the version
#
# Usage: new-version.sh <version> <stage> <prev_version>
# Example: new-version.sh 1.2.3 alpha 1.2.2
# -------------------------------

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

# Set file paths
VERSION_FILE="VERSION.json"
DISTRIBUTION_FILE="distribution/packages/src/rpm/wazuh-indexer.rpm.spec"
CHANGELOG_FILE="CHANGELOG.md"
RELEASE_NOTES_FILE="release-notes/wazuh.release-notes-${VERSION}.md"
BACKUP_DIR="/tmp/wazuh-backups"

# Initialize logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
LOG_FILE="$SCRIPT_DIR/repository_bumper_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting initialization for version=$VERSION, stage=$STAGE, prev_version=$PREVIOUS_VERSION"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Log file: $LOG_FILE"

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

function validate_inputs() {
    NORMALIZED_STAGE=$(echo "$STAGE" | tr '[:upper:]' '[:lower:]')

    if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format." >&2
        exit 1
    fi
    if ! [[ $NORMALIZED_STAGE =~ ^(alpha[0-9]*|beta[0-9]*|rc[0-9]*|stable)$ ]]; then
        echo "Error: Invalid stage format." >&2
        exit 1
    fi
    if ! [[ $PREVIOUS_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid previous version format." >&2
        exit 1
    fi
}

function backup_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/${filename}.bak"
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] Backed up $file to $BACKUP_DIR/${filename}.bak"
    else
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: $file does not exist; skipping backup."
    fi
}

function backup_files() {
    backup_file "$VERSION_FILE"
    backup_file "$DISTRIBUTION_FILE"
    backup_file "$CHANGELOG_FILE"
    backup_file "$RELEASE_NOTES_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Backup of files completed."
}

function update_version_json() {
    TMP_FILE=$(mktemp)
    jq ".version = \"$VERSION\" | .stage = \"$STAGE\"" "$VERSION_FILE" >"$TMP_FILE"
    mv "$TMP_FILE" "$VERSION_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated $VERSION_FILE with version=$VERSION and stage=$STAGE"
}

function update_rpm_spec() {
    CURRENT_DATE=$(date +"%a %b %d %Y")
    ENTRY_LINE1="* $CURRENT_DATE support <info@wazuh.com> - $VERSION"
    ENTRY_LINE2="- More info: https://documentation.wazuh.com/current/release-notes/release-$VERSION.html"

    awk -v l1="$ENTRY_LINE1" -v l2="$ENTRY_LINE2" '
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
    local content
    content=$(echo "$CHANGELOG_TEMPLATE_CONTENT" | sed "s|<VERSION>|$VERSION|g" | sed "s|<PREVIOUS_VERSION>|$PREVIOUS_VERSION|g")
    echo "$content" >"$CHANGELOG_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated $CHANGELOG_FILE with version=$VERSION"
}

function update_release_notes() {
    local today content
    today=$(date +%Y-%m-%d)
    content=$(echo "$RELEASE_NOTES_TEMPLATE_CONTENT" | sed "s|<VERSION>|$VERSION|g" | sed "s|<DATE>|$today|g")
    echo "$content" >"$RELEASE_NOTES_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Created/Updated $RELEASE_NOTES_FILE with version=$VERSION"
}

validate_inputs
backup_files
update_version_json
update_rpm_spec
update_changelog
update_release_notes
echo "[$(date +"%Y-%m-%d %H:%M:%S")] All updates completed successfully."
