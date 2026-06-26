#!/bin/bash
# Creates the artifact directories expected by the builder and transfers
# ownership to the container user (UID 1000).
#
# Optional env: WORKSPACE  (defaults to the current directory)

set -euo pipefail

workspace="${WORKSPACE:-.}"

mkdir -p \
    "${workspace}/artifacts/snapshots" \
    "${workspace}/artifacts/plugins" \
    "${workspace}/artifacts/dist"

chown -R 1000:1000 "${workspace}"
