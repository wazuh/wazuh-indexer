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
function check_project_root_folder() {
    current=$(basename "$(pwd)")

    if [[ "$0" != "./ecs.sh" && "$0" != "ecs.sh" ]]; then
        echo "Run the script from its location"
        usage
        exit 1
    fi
    # Change working directory to the root of the repository
    cd ../..
}

function main() {
  export REPO_PATH="$2"
  export ECS_MODULE="$3"
  local compose_filename="docker/${current}/ecs.yml"
  local compose_cmd="docker compose run -f $compose_filename"

  case $1 in
  up)
      # Main folder created here to grant access to both containers
      mkdir -p artifacts
      $compose_cmd up -d
      ;;
  down)
      $compose_cmd down
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
