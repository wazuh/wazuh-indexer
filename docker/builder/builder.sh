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

    if [[ "$1" != "./builder.sh" && "$1" != "builder.sh" ]]; then
        echo "Run the script from its location"
        usage
        exit 1
    fi
    # Change working directory to the root of the repository
    cd ../..
}

# ====
# Parse arguments
# ====
function parse_args() {

    while getopts ":p:r:R:s:d:a:Dh" arg; do
        case $arg in
        h)
            usage
            exit 1
            ;;
        p)
            INDEXER_PLUGINS_BRANCH=$OPTARG
            ;;
        r)
            INDEXER_REPORTING_BRANCH=$OPTARG
            ;;
        R)
            REVISION=$OPTARG
            ;;
        s)
            IS_STAGE=$OPTARG
            ;;
        d)
            DISTRIBUTION=$OPTARG
            ;;
        a)
            ARCHITECTURE=$OPTARG
            ;;
        D)
            DESTROY="true"
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        ?)
            echo "Invalid option: -${arg}"
            exit 1
            ;;
        esac
    done

    ## Set defaults:
    [ -z "$INDEXER_PLUGINS_BRANCH" ] && INDEXER_PLUGINS_BRANCH="master"
    [ -z "$INDEXER_REPORTING_BRANCH" ] && INDEXER_REPORTING_BRANCH="master"
    [ -z "$REVISION" ] && REVISION="0"
    [ -z "$IS_STAGE" ] && IS_STAGE="false"
    [ -z "$DISTRIBUTION" ] && DISTRIBUTION="rpm"
    [ -z "$ARCHITECTURE" ] && ARCHITECTURE="x64"
}


# ====
# Displays usage
# ====
function usage() {
  echo "Usage: ./builder.sh [-p INDEXER_PLUGINS_BRANCH] [-r INDEXER_REPORTING_BRANCH] [-R REVISION] [-s IS_STAGE] [-d DISTRIBUTION] [-a ARCHITECTURE] [-D (destroy the docker env)]"
}

# ====
# Main function
# ====
function main() {
    check_project_root_folder $0
    compose_file="docker/${current}/compose.yml"
    compose_cmd="docker compose -f $compose_file"
    REPO_PATH=$(pwd)
    VERSION=$(cat VERSION)
    export REPO_PATH
    export VERSION

    parse_args "${@}"
    
    if [[ "$DESTROY" == true || "$DESTROY" == "1" ]]
    then
        $compose_cmd down -v
        exit 0
    fi

    $compose_cmd up --detach --build
}

main "$@"
