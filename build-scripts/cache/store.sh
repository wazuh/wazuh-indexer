#!/bin/bash

# Reads and writes cache entries in a store.
#
#   store.sh get STORE NAME KEY DIR   Extract the entry into DIR. Exit 0 on a hit, 3 on a miss.
#   store.sh put STORE NAME KEY DIR   Publish DIR as the entry. Exit 0 also when it already exists.
#
# STORE is file:///absolute/path (local runs and tests) or s3://bucket/prefix. An entry
# lives at STORE/NAME/KEY/: a payload (tar of the entry files) under a name unique to the
# writer, then manifest.json, written once and last, which names its payload. A reader
# only trusts an entry with a manifest and checks the payload against the SHA-256 in it.
# When two builds publish the same key at once, the first manifest wins and the other
# build keeps going; a payload left without a manifest (a writer that died) blocks
# nothing and goes away with the store's expiry, like every other entry.
#
# DIR, on put, holds the files of the entry and a manifest.json (written by the
# producer, see entrypoint.sh); this script adds the payload name, checksum and size.

set -euo pipefail

MISS=3

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

function usage() {
    echo "Usage: $0 get|put STORE NAME KEY DIR"
}

function log() {
    echo "[cache] $*" >&2
}

# Prints the payload name a manifest points to, refusing anything but our own pattern.
function payload_name() {
    local name
    name="$(jq -r .payload "$1")"
    if ! [[ "${name}" =~ ^payload-[0-9a-f]{16}\.tar$ ]]; then
        log "Unexpected payload name in $1: ${name}"
        return 1
    fi
    echo "${name}"
}

# ---- file:// backend ----

function file_exists() {
    [ -f "$1/manifest.json" ]
}

function file_fetch() {
    local entry="$1" dest="$2"
    cp "${entry}/manifest.json" "${dest}/manifest.json"
    cp "${entry}/$(payload_name "${dest}/manifest.json")" "${dest}/payload.tar"
}

function file_publish() {
    local entry="$1" src="$2" payload tmp
    payload="$(payload_name "${src}/manifest.json")"
    mkdir -p "${entry}"
    cp "${src}/payload.tar" "${entry}/${payload}"
    # Write-once: link(2) fails when the target exists, so the first manifest wins.
    tmp="$(mktemp "${entry}/.manifest.XXXXXX")"
    cp "${src}/manifest.json" "${tmp}"
    if ! ln "${tmp}" "${entry}/manifest.json" 2>/dev/null; then
        rm -f "${tmp}"
        return 1
    fi
    rm -f "${tmp}"
}

# ---- s3:// backend (AWS CLI; credentials and region from the environment) ----

function s3_split() {
    # s3://bucket/prefix/NAME/KEY -> bucket and object key prefix
    local uri="${1#s3://}"
    S3_BUCKET="${uri%%/*}"
    S3_PREFIX="${uri#*/}"
}

function s3_exists() {
    s3_split "$1"
    aws s3api head-object --bucket "${S3_BUCKET}" --key "${S3_PREFIX}/manifest.json" >/dev/null 2>&1
}

function s3_fetch() {
    local entry="$1" dest="$2"
    s3_split "${entry}"
    aws s3api get-object --bucket "${S3_BUCKET}" --key "${S3_PREFIX}/manifest.json" "${dest}/manifest.json" >/dev/null
    aws s3 cp --only-show-errors "${entry}/$(payload_name "${dest}/manifest.json")" "${dest}/payload.tar"
}

function s3_publish() {
    local entry="$1" src="$2" out
    s3_split "${entry}"
    # The payload name is unique to this build, so a plain (multipart) upload is enough.
    aws s3 cp --only-show-errors "${src}/payload.tar" "${entry}/$(payload_name "${src}/manifest.json")"
    # Conditional write: refused when another build wrote the manifest first.
    if out="$(aws s3api put-object --bucket "${S3_BUCKET}" --key "${S3_PREFIX}/manifest.json" \
        --body "${src}/manifest.json" --if-none-match '*' 2>&1)"; then
        return 0
    fi
    if grep -qE 'PreconditionFailed|ConditionalRequestConflict|\(412\)|\(409\)' <<<"${out}"; then
        return 1
    fi
    log "${out}"
    return 2
}

# ---- common ----

function backend_of() {
    case "$1" in
    file:///*) echo file ;;
    s3://*) echo s3 ;;
    *)
        log "Unsupported store: $1 (use file:///path or s3://bucket/prefix)"
        exit 1
        ;;
    esac
}

function entry_of() {
    local store="${1%/}" name="$2" key="$3"
    case "${store}" in
    file://*) echo "${store#file://}/${name}/${key}" ;;
    *) echo "${store}/${name}/${key}" ;;
    esac
}

function cmd_get() {
    local store="$1" name="$2" key="$3" dir="$4" backend entry tmp="${WORK}"
    backend="$(backend_of "${store}")"
    entry="$(entry_of "${store}" "${name}" "${key}")"
    if ! "${backend}_exists" "${entry}"; then
        return "${MISS}"
    fi
    "${backend}_fetch" "${entry}" "${tmp}"

    local want got manifest_key
    manifest_key="$(jq -r .key "${tmp}/manifest.json")"
    want="$(jq -r .payload_sha256 "${tmp}/manifest.json")"
    got="$(sha256sum "${tmp}/payload.tar" | cut -d' ' -f1)"
    if [ "${manifest_key}" != "${key}" ] || [ "${want}" != "${got}" ]; then
        log "${name}: entry ${key} is inconsistent (manifest key ${manifest_key}, payload ${got}, expected ${want}); ignoring it"
        return "${MISS}"
    fi
    rm -rf "${dir}"
    mkdir -p "${dir}"
    tar -xf "${tmp}/payload.tar" -C "${dir}"
    cp "${tmp}/manifest.json" "${dir}/manifest.json"
}

function cmd_put() {
    local store="$1" name="$2" key="$3" dir="$4" backend entry tmp="${WORK}" rc=0
    backend="$(backend_of "${store}")"
    entry="$(entry_of "${store}" "${name}" "${key}")"
    if [ "$(jq -r .key "${dir}/manifest.json")" != "${key}" ]; then
        log "${name}: the manifest in ${dir} is not for key ${key}; not publishing"
        return 1
    fi
    if "${backend}_exists" "${entry}"; then
        log "${name}: ${key} is already published"
        return 0
    fi
    tar -cf "${tmp}/payload.tar" -C "${dir}" --exclude ./manifest.json --sort=name .
    jq --arg name "payload-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n').tar" \
        --arg sha "$(sha256sum "${tmp}/payload.tar" | cut -d' ' -f1)" \
        --argjson size "$(stat -c %s "${tmp}/payload.tar")" \
        '. + {payload: $name, payload_sha256: $sha, payload_bytes: $size}' "${dir}/manifest.json" >"${tmp}/manifest.json"
    "${backend}_publish" "${entry}" "${tmp}" || rc=$?
    case "${rc}" in
    0) log "${name}: published ${key}" ;;
    1) log "${name}: ${key} was published by another build in the meantime; keeping that one" ;;
    *) log "${name}: publishing ${key} failed"; return 1 ;;
    esac
}

function main() {
    [ $# -eq 5 ] || { usage >&2; exit 1; }
    local command="$1"
    shift
    if ! [[ "$2" =~ ^[a-z0-9][a-z0-9-]*$ ]] || ! [[ "$3" =~ ^[0-9a-f]{64}$ ]]; then
        log "Invalid entry name or key: '$2' '$3'"
        exit 1
    fi
    case "${command}" in
    get) cmd_get "$@" ;;
    put) cmd_put "$@" ;;
    *) usage >&2; exit 1 ;;
    esac
}

main "$@"
