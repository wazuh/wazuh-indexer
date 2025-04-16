#!/bin/bash
set -euo pipefail

# -------------------------------
# Wazuh Indexer Version Bump Process
# -------------------------------
# This script updates:
# - VERSION.json: sets new "version" and "stage"
#
# Usage: new-version.sh <version> <stage>
# Example: new-version.sh 1.2.3 alpha
# -------------------------------

function usage() {
    echo "Usage: $0 <version> <stage>"
    echo "  version:        The new version to set in VERSION.json"
    echo "  stage:          The new stage to set in VERSION.json"
    exit 1
}

# Ensure that exactly two arguments are passed
if [ "$#" -ne 2 ]; then
    usage
fi

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is not installed. Please install it and re-run the script." >&2
    exit 1
fi

VERSION=$1
STAGE=$2
VERSION_FILE="VERSION.json"
BACKUP_DIR="/tmp/wazuh-backups"

# Get script directory and define log file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
LOG_FILE="$SCRIPT_DIR/repository_bumper_${TIMESTAMP}.log"

# Redirect stdout and stderr to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting version bump: version=$VERSION, stage=$STAGE"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Log file: $LOG_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup VERSION.json
cp "$VERSION_FILE" "$BACKUP_DIR/VERSION.json.bak"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Backed up VERSION.json to $BACKUP_DIR/VERSION.json.bak"

function navigate_to_project_root() {
    local repo_root_marker
    local script_path
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
    if ! jq ".version = \"$VERSION\" | .stage = \"$STAGE\"" "$VERSION_FILE" >"$TMP_FILE"; then
        echo "Error: Failed to update ${VERSION_FILE}. Exiting."
        rm -f "$TMP_FILE"
        exit 1
    fi
    mv "$TMP_FILE" "$VERSION_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated ${VERSION_FILE} with version=$VERSION and stage=$STAGE"
}

navigate_to_project_root
update_version_json

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Version bump completed successfully."
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Affected file: $VERSION_FILE"
