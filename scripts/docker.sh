#!/bin/bash

# Attaches the project as a volume to a JDK 17 container
# Requires Docker
# Script usage: bash scripts/docker.sh

set -e

# Check the script is being run from the root of the project
if [ ! -f "./scripts/docker.sh" ]; then
    echo "Please run this script from the root of the project"
    echo "Example: bash scripts/docker.sh"
    exit 1
fi

# ====
# Start the container
# ====
run_docker() {
    docker run -ti --rm \
    -v .:/usr/share/opensearch \
    -w /usr/share/opensearch \
    --name wi-dev \
    eclipse-temurin:17 \
    bash
}

run_docker
