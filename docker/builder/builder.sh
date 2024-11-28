#!/bin/bash

# Start container with required tools to build packages
# Requires Docker
# Script usage: bash ./builder.sh

set -e

# ====
# Checks that the script is run from the intended location
# ====
function check_project_root_folder() {
    current=$(basename "$(pwd)")

    if [[ "$0" != "./builder.sh" && "$0" != "builder.sh" ]]; then
        echo "Run the script from its location"
        usage
        exit 1
    fi
    # Change working directory to the root of the repository
    cd ../..
}

# ====
# Displays usage
# ====
function usage() {
    echo "Usage: ./builder.sh {up|down|stop}"
}

# ====
# Main function
# ====
function main() {
    check_project_root_folder "$@"
    compose_file="docker/${current}/compose.yml"
    compose_cmd="docker compose -f $compose_file"
    REPO_PATH=$(pwd)
    VERSION=$(cat VERSION)
    export REPO_PATH
    export VERSION

    case $1 in
    up)
        # Main folder created here to grant access to both containers
        mkdir -p artifacts
        $compose_cmd up -d --build
        ;;
    down)
        $compose_cmd down -v
        ;;
    stop)
        $compose_cmd stop
        ;;
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
