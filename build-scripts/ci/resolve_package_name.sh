#!/bin/bash
# Finds the assembled wazuh-indexer package in DIST_DIR and prints its filename
# to stdout. Exits with an error if zero or more than one package is found.
#
# Optional env: DIST_DIR  (defaults to artifacts/dist)

set -euo pipefail

dist_dir="${DIST_DIR:-artifacts/dist}"

mapfile -t pkgs < <(find "$dist_dir" -maxdepth 1 -type f \
    -name 'wazuh-indexer*' \
    ! -name '*.sha512' \
    ! -name 'wazuh-indexer-min-*' \
    ! -name 'wazuh-indexer-min_*' | sort)

if [ "${#pkgs[@]}" -eq 0 ]; then
    echo "::error::No assembled wazuh-indexer package found in ${dist_dir}" >&2
    ls -lR "$dist_dir" >&2 || true
    exit 1
fi

if [ "${#pkgs[@]}" -gt 1 ]; then
    echo "::error::Multiple candidate packages found in ${dist_dir}:" >&2
    printf '  %s\n' "${pkgs[@]}" >&2
    exit 1
fi

basename "${pkgs[0]}"
