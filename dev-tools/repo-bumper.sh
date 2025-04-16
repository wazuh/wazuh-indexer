#!/bin/bash
set -euo pipefail

# -------------------------------
# Wazuh Indexer Version Bump Process
# -------------------------------
# This script updates:
# - VERSION.json: sets new "version" and "stage"
# - RPM spec file: inserts a new changelog entry after "%changelog"
# - CHANGELOG.md: updates the VERSION section using a template
# - Release notes file: create/update release-notes for the version
#
# Usage: repo-bumper.sh <version> <stage>
# -------------------------------

function usage() {
    echo "Usage: $0 <version> <stage> <prev_version>"
    echo "  version:        The new version to set"
    echo "  stage:          The new stage to set in VERSION.json"
    echo "  prev_version:   The previous version"
    exit 1
}

# Ensure that exactly two arguments are passed
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
# Convert to lowercase for consistent matching
NORMALIZED_STAGE=$(echo "$STAGE" | tr '[:upper:]' '[:lower:]')

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format. Expected format is X.Y.Z (e.g., 1.2.3)." >&2
    exit 1
fi

# Validate stage format (e.g., alpha, alpha1, beta2, rc3, stable)
if ! [[ $NORMALIZED_STAGE =~ ^(alpha[0-9]*|beta[0-9]*|rc[0-9]*|stable)$ ]]; then
    echo "Error: Invalid stage. Expected values like: alpha, beta2, rc, stable, etc." >&2
    exit 1
fi

# Validate previous version format (if extracted)
if ! [[ $PREVIOUS_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid previous version format. Expected format is X.Y.Z (e.g., 1.2.3)." >&2
    exit 1
fi

# Define file paths
VERSION_FILE="VERSION.json"
DISTRIBUTION_FILE="distribution/packages/src/rpm/wazuh-indexer.rpm.spec"
CHANGELOG_FILE="CHANGELOG.md"
RELEASE_NOTES_FILE="release-notes/wazuh.release-notes-${VERSION}.md"

# Directory where backups will be stored
BACKUP_DIR="/tmp/wazuh-backups"

# Templates for CHANGELOG and Release Notes
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

function backup_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/${filename}.bak"
    else
        echo "Warning: '$file' does not exist; skipping backup."
    fi
}

function backup_files() {
    backup_file "$VERSION_FILE"
    backup_file "$DISTRIBUTION_FILE"
    backup_file "$CHANGELOG_FILE"
    backup_file "$RELEASE_NOTES_FILE"
    echo "Backup of files completed. Backups are stored in $BACKUP_DIR."
}

function update_version_json() {
    TMP_FILE=$(mktemp)
    if [ ! -f "$VERSION_FILE" ]; then
        echo "Error: ${VERSION_FILE} does not exist. Exiting."
        exit 1
    fi
    if ! jq empty "$VERSION_FILE" &>/dev/null; then
        echo "Error: ${VERSION_FILE} is not a valid JSON file. Exiting."
        exit 1
    fi
    if ! jq ".version = \"$VERSION\" | .stage = \"$STAGE\"" "$VERSION_FILE" > "$TMP_FILE"; then
        echo "Error: Failed to update ${VERSION_FILE}. Exiting."
        rm -f "$TMP_FILE"
        exit 1
    fi
    mv "$TMP_FILE" "$VERSION_FILE"
    echo "Updated ${VERSION_FILE} with version: $VERSION and stage: $STAGE."
}

function update_rpm_spec() {
    if [ ! -f "$DISTRIBUTION_FILE" ]; then
        echo "Error: ${DISTRIBUTION_FILE} does not exist. Exiting."
        exit 1
    fi
    if ! grep -q "%changelog" "$DISTRIBUTION_FILE"; then
        echo "Error: %changelog section not found in ${DISTRIBUTION_FILE}. Exiting."
        exit 1
    fi
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
    echo "Updated ${DISTRIBUTION_FILE} with changelog entry for version: $VERSION."
}

function update_changelog() {
    if [ ! -f "$CHANGELOG_FILE" ]; then
        echo "Error: ${CHANGELOG_FILE} does not exist. Exiting."
        exit 1
    fi
    CHANGELOG_CONTENT=$(echo "$CHANGELOG_TEMPLATE_CONTENT" |
        sed "s|<VERSION>|${VERSION}|g" |
        sed "s|<PREVIOUS_VERSION>|${PREVIOUS_VERSION}|g")
    echo "$CHANGELOG_CONTENT" >"$CHANGELOG_FILE"
    echo "Updated ${CHANGELOG_FILE} with version: $VERSION."
}

function update_release_notes() {
    if [ ! -f "$RELEASE_NOTES_FILE" ]; then
        echo "Error: ${RELEASE_NOTES_FILE} does not exist. Exiting."
        exit 1
    fi
    TODAY=$(date +%Y-%m-%d)
    RELEASE_NOTES_CONTENT=$(echo "$RELEASE_NOTES_TEMPLATE_CONTENT" |
        sed "s|<VERSION>|${VERSION}|g" |
        sed "s|<DATE>|${TODAY}|g")
    echo "$RELEASE_NOTES_CONTENT" >"$RELEASE_NOTES_FILE"
    echo "Created/Updated ${RELEASE_NOTES_FILE} with version: $VERSION."
}

echo "Starting the update process for version: $VERSION and stage: $STAGE."
backup_files
update_version_json
update_rpm_spec
update_changelog
update_release_notes
echo "All updates completed successfully."
