#!/bin/bash
# Queries the GitHub Releases API and prints three lines to stdout:
#   previous_version=<latest release before current, any major>
#   previous_4x_version=<latest 4.x release>
#   update_tests=<true when previous_version is 5.0.0 or later, false otherwise>
# Versions are compared with `sort -V`, never as plain strings.
# Exits with an error when no 4.x release is found, since the upgrade tests need it.
#
# Required env: GITHUB_TOKEN
# Required env: CURRENT_VERSION  (e.g. "5.0.0")

set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${CURRENT_VERSION:?CURRENT_VERSION is required}"

response=$(curl -sfSL \
    --retry 3 --retry-all-errors --retry-delay 5 \
    --connect-timeout 10 --max-time 30 \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/wazuh/wazuh-indexer/releases?per_page=100")

# Stable releases only (drops alpha, beta and rc tags)
releases=$(jq -r '.[].tag_name' <<< "$response" \
  | sed 's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)

# Highest release strictly lower than the current version
previous_version=$(printf '%s\n' "$releases" "$CURRENT_VERSION" \
  | sort -Vu \
  | grep -x -B1 -F "$CURRENT_VERSION" \
  | grep -vx -F "$CURRENT_VERSION" || true)

previous_4x_version=$(echo "$releases" \
  | grep -E '^4\.' \
  | sort -V \
  | tail -n1 || true)

if [[ -z "$previous_4x_version" ]]; then
    echo "Error: no 4.x release found in wazuh/wazuh-indexer" >&2
    exit 1
fi

# true when previous_version >= 5.0.0
update_tests=false
if [[ -n "$previous_version" && "$(printf '%s\n' 5.0.0 "$previous_version" | sort -V | head -n1)" == "5.0.0" ]]; then
    update_tests=true
fi

echo "previous_version=${previous_version}"
echo "previous_4x_version=${previous_4x_version}"
echo "update_tests=${update_tests}"
