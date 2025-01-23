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
    repo_root_marker=".github"
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    if [[ "$script_path" == "/" ]]; then
        echo "Error: Unable to find the repository root."
        exit 1
    fi

    cd "$script_path"
}

# ====
# Displays usage information
# ====
function usage() {
    echo "Usage: $0 {run|down|stop} <ECS_MODULE> [REPO_PATH]"
    exit 1
}

function main() {
    local compose_filename="ecs/generator/mapping-generator.yml"
    local compose_command
    local module
    local repo_path

    navigate_to_project_root

    compose_command="docker compose -f $compose_filename"

    case $1 in
        run)
            if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
                usage
            fi
            module="$2"
            repo_path="${3:-$(pwd)}"

            # Start the container with the required env variables
            ECS_MODULE="$module" REPO_PATH="$repo_path" $compose_command up
            # The containers are stopped after each execution
            $compose_command stop
            ;;
        down)
            $compose_command down
            ;;
        stop)
            $compose_command stop
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
