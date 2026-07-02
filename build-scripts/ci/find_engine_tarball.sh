#!/bin/bash
# Locates the wazuh-engine tarball in ENGINE_DIR and prints its path to stdout.
#
# Optional env: ENGINE_DIR  (defaults to artifacts/engine)

set -euo pipefail

engine_dir="${ENGINE_DIR:-artifacts/engine}"

tarball=$(find "$engine_dir" -name 'wazuh-engine-*-linux-*.tar.gz' | head -n1)

if [ -z "$tarball" ]; then
    echo "::error::Wazuh Engine tarball not found in ${engine_dir}" >&2
    ls -lR "$engine_dir" >&2 || true
    exit 1
fi

echo "$tarball"
