#!/bin/bash

# Checks store.sh against a store: miss, publish, hit, a second publication of the same
# key, concurrent publications, a corrupted payload and invalid arguments.
#
# Usage: bash build-scripts/cache/test_store.sh [STORE]
#   STORE defaults to a temporary file:// store. For S3, pass s3://bucket/prefix with the
#   AWS credentials (and AWS_ENDPOINT_URL for an S3-compatible server) in the environment.
#   The test writes under a random prefix and leaves it to the store expiry.

set -euo pipefail

CACHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_SH="${CACHE_DIR}/store.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

STORE="${1:-file://${WORK}/store}"
STORE="${STORE%/}/test-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
NAME="test-entry"
KEY="$(printf 'key-1' | sha256sum | cut -d' ' -f1)"
failures=0

function pass() { echo "PASS  $1"; }
function fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

# make_entry <dir> <content>
function make_entry() {
    mkdir -p "$1/sub"
    echo "$2" >"$1/sub/file.txt"
    jq -n --arg key "${KEY}" --arg content "$2" '{key: $key, content: $content}' >"$1/manifest.json"
}

function get() { bash "${STORE_SH}" get "${STORE}" "${NAME}" "$1" "$2" 2>"${WORK}/get.err"; }

rc=0; get "${KEY}" "${WORK}/out" || rc=$?
[ "${rc}" -eq 3 ] && pass "a missing entry is a miss (exit 3)" || fail "a missing entry returned ${rc}, not 3"

make_entry "${WORK}/a" "first"
bash "${STORE_SH}" put "${STORE}" "${NAME}" "${KEY}" "${WORK}/a" 2>/dev/null && pass "publish" || fail "publish"

if get "${KEY}" "${WORK}/out" && [ "$(cat "${WORK}/out/sub/file.txt")" = "first" ] &&
    [ "$(jq -r .key "${WORK}/out/manifest.json")" = "${KEY}" ]; then
    pass "a published entry is restored with its files and manifest"
else
    fail "a published entry is not restored as published"
fi

make_entry "${WORK}/b" "second"
bash "${STORE_SH}" put "${STORE}" "${NAME}" "${KEY}" "${WORK}/b" 2>/dev/null &&
    get "${KEY}" "${WORK}/out" && [ "$(cat "${WORK}/out/sub/file.txt")" = "first" ] &&
    pass "publishing an existing key succeeds and keeps the first entry" ||
    fail "publishing an existing key replaced it or failed"

# Concurrent publications of a new key: exactly one wins, every writer succeeds.
KEY2="$(printf 'key-2' | sha256sum | cut -d' ' -f1)"
pids=()
for i in 1 2 3 4 5 6; do
    make_entry "${WORK}/c${i}" "writer-${i}"
    jq --arg key "${KEY2}" '.key = $key' "${WORK}/c${i}/manifest.json" >"${WORK}/m" && mv "${WORK}/m" "${WORK}/c${i}/manifest.json"
    bash "${STORE_SH}" put "${STORE}" "${NAME}" "${KEY2}" "${WORK}/c${i}" 2>>"${WORK}/race.log" &
    pids+=($!)
done
writers_ok=true
for pid in "${pids[@]}"; do wait "${pid}" || writers_ok=false; done
if [ "${writers_ok}" = true ] && get "${KEY2}" "${WORK}/race" &&
    [ "$(cat "${WORK}/race/sub/file.txt")" = "$(jq -r .content "${WORK}/race/manifest.json")" ]; then
    pass "6 concurrent publications: all succeed, one consistent entry wins ($(cat "${WORK}/race/sub/file.txt"))"
else
    fail "concurrent publications: writers ok=${writers_ok}; $(cat "${WORK}/race.log")"
fi

# A corrupted payload is a miss, not a restore.
if [[ "${STORE}" == file://* ]]; then
    entry="${STORE#file://}/${NAME}/${KEY}"
    echo "garbage" >>"${entry}/$(jq -r .payload "${entry}/manifest.json")"
    rc=0; get "${KEY}" "${WORK}/bad" || rc=$?
    [ "${rc}" -eq 3 ] && [ ! -e "${WORK}/bad" ] && pass "a corrupted payload is a miss" || fail "a corrupted payload returned ${rc}"
fi

rc=0; bash "${STORE_SH}" get "${STORE}" "${NAME}" "not-a-key" "${WORK}/x" 2>/dev/null || rc=$?
[ "${rc}" -eq 1 ] && pass "an invalid key is refused" || fail "an invalid key returned ${rc}"
rc=0; bash "${STORE_SH}" get "${STORE}" "../escape" "${KEY}" "${WORK}/x" 2>/dev/null || rc=$?
[ "${rc}" -eq 1 ] && pass "an invalid entry name is refused" || fail "an invalid entry name returned ${rc}"
make_entry "${WORK}/d" "mismatch"
rc=0; bash "${STORE_SH}" put "${STORE}" "${NAME}" "$(printf 'key-3' | sha256sum | cut -d' ' -f1)" "${WORK}/d" 2>/dev/null || rc=$?
[ "${rc}" -ne 0 ] && pass "a manifest for another key is not published" || fail "a manifest for another key was published"

echo
if [ "${failures}" -gt 0 ]; then
    echo "${failures} check(s) failed"
    exit 1
fi
echo "All checks passed (${STORE})"
