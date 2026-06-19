#!/bin/bash

# Run a DEB package test body inside a privileged, systemd-enabled Ubuntu
# container.
#
# The CI runner is itself a container in which systemd is not running as PID 1,
# so the wazuh-indexer maintainer scripts (preinst/postinst call `systemctl`)
# cannot run directly on the runner host. This helper boots a throwaway
# systemd init container - the Debian-family equivalent of the redhat/ubi9-init
# image used by the RPM tests - waits for systemd to come up, runs the provided
# test body via `docker exec`, and always tears the container down afterwards.
#
# Usage: run_in_systemd_container.sh <workspace> <script-body>
#
# Arguments:
# - workspace     [required] Host path checked out by the workflow. Its
#                            artifacts/dist and build-scripts directories are
#                            bind-mounted into the container at /artifacts/dist
#                            and /build-scripts.
# - script-body   [required] Bash snippet executed inside the container.

set -e

WORKSPACE="$1"
SCRIPT_BODY="$2"

if [ -z "$WORKSPACE" ] || [ -z "$SCRIPT_BODY" ]; then
    echo "Usage: $0 <workspace> <script-body>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Systemd-enabled Ubuntu image. By default it is built locally from AWS ECR
# Public (no Docker Hub pull-rate limits on CI), so the first call builds it and
# the rest hit the layer cache. Override SYSTEMD_IMAGE to use a prebuilt image
# (e.g. one pushed to an internal registry) and skip the build.
SYSTEMD_IMAGE="${SYSTEMD_IMAGE:-wazuh-indexer-systemd-test:jammy}"

if ! docker image inspect "$SYSTEMD_IMAGE" >/dev/null 2>&1; then
    echo "Building systemd test image ${SYSTEMD_IMAGE}..."
    # The Dockerfile has no COPY/ADD, so an empty build context keeps it fast.
    docker build -t "$SYSTEMD_IMAGE" \
        -f "${SCRIPT_DIR}/builder/systemd-test.Dockerfile" \
        "${SCRIPT_DIR}/builder"
fi

cid=$(docker run -d --rm \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -v "${WORKSPACE}/artifacts/dist:/artifacts/dist" \
    -v "${WORKSPACE}/build-scripts/:/build-scripts/" \
    "$SYSTEMD_IMAGE" /sbin/init)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

# Wait for systemd to finish booting before exercising any service units.
ready=false
for _ in $(seq 1 30); do
    state=$(docker exec "$cid" systemctl is-system-running 2>/dev/null || true)
    case "$state" in
    running | degraded)
        ready=true
        break
        ;;
    esac
    sleep 1
done

if [ "$ready" != true ]; then
    echo "ERROR: systemd did not become ready in the container (last state: ${state:-unknown})"
    docker logs "$cid" || true
    exit 1
fi

docker exec "$cid" bash -c "$SCRIPT_BODY"
