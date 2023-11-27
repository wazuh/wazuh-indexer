#!/bin/bash

# Attaches the project as a volume to a JDK 17 container
# Requires Docker
# Script usage: bash ./docker.sh

set -e

# Change working directory to the root of the repository
cd "${0%/*}/.."


# ====
# Main function
# ====
main() {
    COMPOSE_FILE=docker/dev.yml
    REPO_PATH=$(pwd)
    VERSION=$(bash "$REPO_PATH/docker/get_version.sh")
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
    export REPO_PATH
    export VERSION

    case $1 in
    up)
        $COMPOSE_CMD up -d
        ;;
    down)
        $COMPOSE_CMD down
        ;;
    stop)
        $COMPOSE_CMD stop
        ;;
    *)
        echo "Usage: $0 {up|down|stop} [security]"
        exit 1
        ;;
    esac
}


main "$@"