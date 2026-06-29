#!/bin/bash
# Ensures the Docker daemon is running and Docker Compose v2 is available.
# Both checks are no-ops when already satisfied (e.g. the amd runner).
#
# Workarounds for the ARM runner:
#   - The image doesn't start the Docker daemon; we start it here with the vfs
#     storage driver to avoid overlay-on-overlay mount failures inside the
#     containerized runner.
#   - The image ships without the Docker Compose plugin; we install it here.
#
# TODO: remove once both are baked into the runner image.

set -euo pipefail

COMPOSE_VERSION="${COMPOSE_VERSION:-v2.29.7}"

# --- Docker daemon ---
if docker info >/dev/null 2>&1; then
    echo "Docker daemon already running."
else
    echo "Starting Docker daemon with the vfs storage driver..."
    # vfs + the classic image store avoid overlay mounts, which fail
    # (overlay-on-overlay) inside the containerized runner.
    mkdir -p /etc/docker
    echo '{"storage-driver":"vfs","features":{"containerd-snapshotter":false}}' > /etc/docker/daemon.json
    if command -v systemctl >/dev/null 2>&1 && systemctl start docker 2>/dev/null; then :
    elif command -v service >/dev/null 2>&1 && service docker start 2>/dev/null; then :
    else dockerd >/tmp/dockerd.log 2>&1 &
    fi
    for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
    chmod 666 /var/run/docker.sock 2>/dev/null || true
    docker info
fi

# --- Docker Compose ---
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose already available."
else
    echo "Installing Docker Compose ${COMPOSE_VERSION}..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL \
        "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    docker compose version
fi
