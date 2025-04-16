#!/bin/bash

# Check for required parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <version> <stage>"
    echo "  version:        The new version to set in VERSION.json"
    echo "  stage:          The new stage to set in VERSION.json"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "Error: jq is not installed. Please install jq to use this script."
    exit 1
fi

VERSION="$1"
STAGE="$2"
FILE="VERSION.json"

# Parameters validations
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Error: Invalid version format." >&2
    exit 1
fi
normalized_stage=$(echo "$STAGE" | tr '[:upper:]' '[:lower:]')
if ! [[ $normalized_stage =~ ^(alpha[0-9]*|beta[0-9]*|rc[0-9]*|stable)$ ]]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Error: Invalid stage format." >&2
    exit 1
fi

# Initialize logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
LOG_FILE="$SCRIPT_DIR/repository_bumper_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Update the file using jq
jq --arg v "$VERSION" --arg s "$STAGE" \
    '.version = $v | .stage = $s' "$FILE" >"${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Updated $FILE with version=$VERSION and stage=$STAGE"
