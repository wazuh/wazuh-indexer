#!/bin/bash

# allocator_setup_environment.sh
# This script allocates a machine to perform smoke tests for the RPM and DEB distributions.
#
# Usage:
#   allocator_setup_environment.sh [--dry-run] <distribution> <architecture> <run_id>
#
# Arguments:
#   distribution    [required] Target distribution: rpm or deb.
#   architecture    [required] Target architecture: x64 or arm64.
#   run_id          [required] Unique run ID used for naming the instance.
# Options:
#   --dry-run       Show the command that would be run, but do not execute it.

set -euo pipefail

# Read version info from VERSION.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/../VERSION.json"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "❌ Error: VERSION.json not found at $VERSION_FILE"
    exit 1
fi

RELEASE="$(grep -oP '"version"\s*:\s*"\K[^"]+' "$VERSION_FILE")"
STAGE="$(grep -oP '"stage"\s*:\s*"\K[^"]+' "$VERSION_FILE")"
EXECUTION_ID="${GITHUB_RUN_ID:-unknown}"

# Initialize variables
DRY_RUN=false
POSITIONAL_ARGS=()

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] <distribution> <architecture> <run_id>"
      echo
      echo "Arguments:"
      echo "  distribution    Target distribution: rpm or deb"
      echo "  architecture    Target architecture: x64 or arm64"
      echo "  run_id          Unique identifier to be used in the instance name"
      echo
      echo "Options:"
      echo "  --dry-run       Show the command that would be executed, without running it"
      exit 0
      ;;
    -*)
      echo "❌ Unknown option: $arg"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

# Check that we have exactly three arguments left
if [[ $# -ne 3 ]]; then
    echo "❌ Error: Distribution, architecture and run_id are required."
    echo "Try '$0 --help' for usage."
    exit 1
fi

DISTRIBUTION="$1"
ARCH="$2"
RUN_ID="$3"

# Constants
INVENTORY_OUTPUT="/tmp/inventory.yaml"
TRACK_OUTPUT="/tmp/track.yaml"
WORKDIR="/tmp/indexer"
LABEL_TEAM="indexer"
TERMINATION_DATE="1d"
ALLOCATOR_SCRIPT="wazuh-automation/deployability/modules/allocation/main.py"

# Distribution and architecture based settings
case "${DISTRIBUTION}-${ARCH}" in
    rpm-x64)
        COMPOSITE_NAME="linux-centos-9-amd64"
        INSTANCE_NAME="indexer_amd_${RUN_ID}"
        ;;
    rpm-arm64)
        COMPOSITE_NAME="linux-centos-8-arm64"
        INSTANCE_NAME="indexer_arm_${RUN_ID}"
        ;;
    deb-x64)
        COMPOSITE_NAME="linux-ubuntu-24.04-amd64"
        INSTANCE_NAME="indexer_deb_amd_${RUN_ID}"
        ;;
    deb-arm64)
        COMPOSITE_NAME="linux-ubuntu-24.04-arm64"
        INSTANCE_NAME="indexer_deb_arm_${RUN_ID}"
        ;;
    *)
        echo "❌ Error: Invalid distribution '$DISTRIBUTION' or architecture '$ARCH'. Valid options are: rpm, deb and x64, arm64."
        exit 1
        ;;
esac

echo "🚀 Starting deployment for distribution: $DISTRIBUTION, architecture: $ARCH, run_id: $RUN_ID"
echo "🔧 Instance name: $INSTANCE_NAME"
echo "📦 Composite name: $COMPOSITE_NAME"

# Build the command
CMD=(
    python3 "$ALLOCATOR_SCRIPT"
    --action create
    --provider aws
    --size large
    --composite-name "$COMPOSITE_NAME"
    --instance-name "$INSTANCE_NAME"
    --inventory-output "$INVENTORY_OUTPUT"
    --track-output "$TRACK_OUTPUT"
    --label-team "$LABEL_TEAM"
    --label-termination-date "$TERMINATION_DATE"
    --working-dir "$WORKDIR"
    --custom-tags "Organization:xdrsiem,CreatedBy:github-actions,FixedResource:false,Sensitive:false,Product:wazuh-indexer,Purpose:package-build,Release:${RELEASE},Stage:${STAGE},ExecutionId:${EXECUTION_ID}"
)

# Execute or simulate
if $DRY_RUN; then
    echo "🧪 Dry run mode enabled. The following command would be executed:"
    printf '%q ' "${CMD[@]}"
    echo
else
    "${CMD[@]}"
fi
