#!/bin/bash
# Packs and unpacks the stage contract that the build job hands to the package
# job (wazuh/wazuh-indexer#2130). Runs on the CI host, never in the builder
# container: the container gets no cloud credentials.
#
#   pack   -d DIST -a ARCH -r REVISION -v VERSION -o OUT_DIR
#       Checks the contract (build-scripts/check_stage_contract.sh) and writes
#       OUT_DIR/contract.tar and OUT_DIR/contract.json (manifest with the tar's
#       sha256). Upload contract.tar FIRST and contract.json LAST, so that an
#       interrupted upload never leaves a manifest that matches a partial tar.
#
#   unpack -d DIST -a ARCH -i IN_DIR
#       Checks that IN_DIR/contract.tar matches IN_DIR/contract.json, that the
#       manifest belongs to this commit and target, that the tar only holds the
#       files listed in the manifest, and extracts it into the workspace.
#       Run it before build-scripts/ci/prepare_workspace.sh, so that the files
#       end up owned by the container user.
#
# Optional env: WORKSPACE (defaults to the current directory)
#               GITHUB_SHA, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT (recorded by pack;
#               GITHUB_SHA is also checked by unpack when set)
#
# Requires only bash, coreutils, tar and python3 (the arm64 CI runner image has
# neither zip nor 7z, and jq is not guaranteed).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="${WORKSPACE:-.}"

function usage() {
    echo "Usage:"
    echo "  $0 pack   -d DISTRIBUTION -a ARCHITECTURE -r REVISION -v VERSION -o OUT_DIR"
    echo "  $0 unpack -d DISTRIBUTION -a ARCHITECTURE -i IN_DIR"
}

function pack() {
    local distribution="" architecture="" revision="" version="" out_dir=""
    local OPTIND arg
    while getopts ":d:a:r:v:o:" arg; do
        case $arg in
        d) distribution=$OPTARG ;;
        a) architecture=$OPTARG ;;
        r) revision=$OPTARG ;;
        v) version=$OPTARG ;;
        o) out_dir=$OPTARG ;;
        *) usage >&2; exit 1 ;;
        esac
    done
    if [ -z "$distribution" ] || [ -z "$architecture" ] || [ -z "$revision" ] || [ -z "$version" ] || [ -z "$out_dir" ]; then
        usage >&2
        exit 1
    fi

    mkdir -p "$out_dir"
    local list="${out_dir}/contract.files"
    bash "${script_dir}/../check_stage_contract.sh" \
        -d "$distribution" -a "$architecture" -r "$revision" -v "$version" -w "$workspace" -l >"$list"

    rm -f "${out_dir}/contract.tar" "${out_dir}/contract.json"
    # Uncompressed: the zips and packages inside are already compressed.
    tar -cf "${out_dir}/contract.tar" -C "$workspace" -T "$list"

    python3 -I - "$out_dir" "$workspace" "$list" "$distribution" "$architecture" "$revision" "$version" <<'PY'
import hashlib, json, os, sys
out_dir, workspace, file_list, dist, arch, revision, version = sys.argv[1:8]
tar_path = os.path.join(out_dir, "contract.tar")
digest = hashlib.sha256()
with open(tar_path, "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
        digest.update(chunk)
with open(file_list) as f:
    paths = [p.strip() for p in f if p.strip()]
manifest = {
    "distribution": dist,
    "architecture": arch,
    "revision": revision,
    "version": version,
    "github_sha": os.environ.get("GITHUB_SHA", ""),
    "run_id": os.environ.get("GITHUB_RUN_ID", ""),
    "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""),
    "tar_sha256": digest.hexdigest(),
    "tar_bytes": os.path.getsize(tar_path),
    "files": [{"path": p, "bytes": os.path.getsize(os.path.join(workspace, p))} for p in paths],
}
with open(os.path.join(out_dir, "contract.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(f"Packed {len(paths)} files, {manifest['tar_bytes']} bytes, sha256 {manifest['tar_sha256']}")
PY
    rm -f "$list"
}

function unpack() {
    local distribution="" architecture="" in_dir=""
    local OPTIND arg
    while getopts ":d:a:i:" arg; do
        case $arg in
        d) distribution=$OPTARG ;;
        a) architecture=$OPTARG ;;
        i) in_dir=$OPTARG ;;
        *) usage >&2; exit 1 ;;
        esac
    done
    if [ -z "$distribution" ] || [ -z "$architecture" ] || [ -z "$in_dir" ]; then
        usage >&2
        exit 1
    fi

    local tar_path="${in_dir}/contract.tar"
    local manifest="${in_dir}/contract.json"
    if [ ! -f "$tar_path" ] || [ ! -f "$manifest" ]; then
        echo "::error::Stage contract not found in ${in_dir} (expected contract.tar and contract.json)" >&2
        exit 1
    fi

    local members
    members=$(mktemp)
    # shellcheck disable=SC2064  # expand now: members is local to this function
    trap "rm -f '$members'" EXIT
    tar -tf "$tar_path" >"$members"

    python3 -I - "$tar_path" "$manifest" "$members" "$distribution" "$architecture" <<'PY'
import hashlib, json, os, sys
tar_path, manifest_path, members_path, dist, arch = sys.argv[1:6]
with open(manifest_path) as f:
    manifest = json.load(f)
errors = []
digest = hashlib.sha256()
with open(tar_path, "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
        digest.update(chunk)
if digest.hexdigest() != manifest.get("tar_sha256"):
    errors.append("contract.tar does not match the sha256 in contract.json (partial or mixed upload?)")
if (manifest.get("distribution"), manifest.get("architecture")) != (dist, arch):
    errors.append(f"contract is for {manifest.get('distribution')}-{manifest.get('architecture')}, expected {dist}-{arch}")
sha = os.environ.get("GITHUB_SHA", "")
if sha and manifest.get("github_sha") != sha:
    errors.append(f"contract was built from commit {manifest.get('github_sha')}, this job is on {sha}")
expected = {entry["path"] for entry in manifest.get("files", [])}
with open(members_path) as f:
    members = {m.strip() for m in f if m.strip()}
if members != expected:
    errors.append(f"contract.tar members differ from the manifest: extra={sorted(members - expected)} missing={sorted(expected - members)}")
for p in expected:
    if p.startswith("/") or ".." in p.split("/"):
        errors.append(f"unsafe path in the manifest: {p}")
if errors:
    for e in errors:
        print(f"::error::{e}", file=sys.stderr)
    sys.exit(1)
print(f"Contract OK: {len(expected)} files from run {manifest.get('run_id')} attempt {manifest.get('run_attempt')}")
PY

    tar -xf "$tar_path" -C "$workspace" --no-same-owner
}

command="${1:-}"
shift || true
case "$command" in
pack) pack "$@" ;;
unpack) unpack "$@" ;;
*)
    usage >&2
    exit 1
    ;;
esac
