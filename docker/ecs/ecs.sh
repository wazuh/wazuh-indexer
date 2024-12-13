#!/bin/bash

# Run the ECS generator tool container.
# Requirements:
#   - Docker
#   - Docker Compose

set -e

# The container is built only if needed, the tool can be executed several times
# for different modules in the same build since the script runs as entrypoint

# ====
# Checks that the script is run from the intended location
# ====
function navigate_to_project_root() {
    local repo_root_marker
    local script_path
    local script_abs_path

    repo_root_marker=".github"
    script_path=$(dirname "$0")
    script_abs_path=$(cd "$script_path" && pwd)

    while [[ "$script_abs_path" != "/" ]] && [[ ! -f "$script_abs_path/$repo_root_marker" ]]; do
        script_abs_path=$(dirname "$script_abs_path")
    done

    if [[ "$script_abs_path" == "/" ]]; then
        echo "Unable to find the repository root."
        exit 1
    fi

    cd "$script_abs_path"
}

# ====
# Displays usage information
# ====
function usage() {
    echo "Usage: $0 {up|down|stop} <ECS_MODULE> [REPO_PATH]"
    exit 1
}

function main() {
    local compose_filename
    local compose_cmd
    local module
    local repo_path

    if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
        usage
    fi

    navigate_to_project_root

    module="$2"
    if [[ -n "$3" ]]; then
        repo_path="$3"
    else
        repo_path="$(pwd)"
    fi

    compose_filename="docker/ecs/ecs.yml"
    compose_cmd="docker-compose -f $compose_filename"

    case $1 in
        up)
            # Main folder created here to grant access to both containers
            mkdir -p artifacts
            $compose_cmd ECS_MODULE="$module" REPO_PATH="$repo_path" up -d
            ;;
        down)
            $compose_cmd down
            ;;
        stop)
            $compose_cmd stop
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
