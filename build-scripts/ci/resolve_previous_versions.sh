#!/bin/bash
# Queries the GitHub Releases API and prints two lines to stdout:
#   previous_version=<latest release before current, any major>
#   previous_4x_version=<latest 4.x release>
# Both values are empty strings when no matching release is found.
#
# Required env: GITHUB_TOKEN
# Required env: CURRENT_VERSION  (e.g. "5.0.0")

set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${CURRENT_VERSION:?CURRENT_VERSION is required}"

releases=$(curl -sfSL \
    --retry 3 --retry-all-errors --retry-delay 5 \
    --connect-timeout 10 --max-time 30 \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/wazuh/wazuh-indexer/releases \
  | jq -r '.[].tag_name' \
  | grep -vE 'alpha|beta|rc' \
  | sed 's/^v//')

previous_version=$(echo "$releases" \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | grep -v "^${CURRENT_VERSION}$" \
  | sort -V \
  | awk -v current="$CURRENT_VERSION" '$0 < current' \
  | tail -n1 || true)

previous_4x_version=$(echo "$releases" \
  | grep -E '^4\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n1 || true)

echo "previous_version=${previous_version}"
echo "previous_4x_version=${previous_4x_version}"
