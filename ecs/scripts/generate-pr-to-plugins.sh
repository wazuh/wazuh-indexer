#!/usr/bin/env bash

# Constants
ECS_VERSION=${ECS_VERSION:-v8.11.0}
MAPPINGS_SUBPATH="mappings/${ECS_VERSION}/generated/elasticsearch/legacy/template.json"
TEMPLATES_PATH="plugins/setup/src/main/resources/"
PLUGINS_REPO="wazuh/wazuh-indexer-plugins"
CURRENT_PATH=$(pwd)
OUTPUT_PATH=${OUTPUT_PATH:-"$CURRENT_PATH"/../output}
BASE_BRANCH=${BASE_BRANCH:-master}
PLUGINS_LOCAL_PATH=${PLUGINS_LOCAL_PATH:-"$CURRENT_PATH"/../wazuh-indexer-plugins}

# Committer's identity
COMMITER_EMAIL=${COMMITER_EMAIL:-$(git config user.email)}
COMMITTER_USERNAME=${COMMITTER_USERNAME:-$(git config user.name)} # Human readable username

# Global variables
declare -a relevant_modules
declare -A module_to_file

# Check if a command exists on the system.
# Parameters:
#   $1: Command to check.
command_exists() {
    command -v "$1" &> /dev/null
}

# Validate that all required dependencies are installed.
validate_dependencies() {
    local required_commands=("docker" "docker-compose" "gh")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            echo "Error: $cmd is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Check if the script is being executed in a GHA Workflow
check_running_on_gha() {
    if [[ -n "${GITHUB_RUN_ID}" ]]; then
        return 0
    else
        return 1
    fi
}

# Detect modified ECS modules by comparing the current branch with the base branch.
detect_modified_modules() {
    echo
    echo "---> Fetching and extracting modified ECS modules..."
    git fetch origin +refs/heads/master:refs/remotes/origin/master
    local modified_files
    local updated_modules=()
    modified_files=$(git diff --name-only origin/"$BASE_BRANCH")

    for file in $modified_files; do
        if [[ $file == ecs/* ]]; then
            ecs_module=$(echo "$file" | cut -d'/' -f2)
            if [[ ! " ${updated_modules[*]} " =~ ${ecs_module} ]]; then
                updated_modules+=("$ecs_module")
            fi
        fi
    done
    echo "Updated ECS modules: ${updated_modules[*]}"

    # Mapping section
    module_to_file=(
        [agent]="index-template-agent.json"
        [alerts]="index-template-alerts.json"
        [command]="index-template-commands.json"
        [states-fim]="index-template-fim.json"
        [states-inventory-hardware]="index-template-hardware.json"
        [states-inventory-hotfixes]="index-template-hotfixes.json"
        [states-inventory-networks]="index-template-networks.json"
        [states-inventory-packages]="index-template-packages.json"
        [states-inventory-ports]="index-template-ports.json"
        [states-inventory-processes]="index-template-processes.json"
        [states-inventory-scheduled-commands]="index-template-scheduled-commands.json"
        [states-inventory-system]="index-template-system.json"
        [states-vulnerabilities]="index-template-vulnerabilities.json"
    )

    relevant_modules=()
    for ecs_module in "${updated_modules[@]}"; do
        if [[ -n "${module_to_file[$ecs_module]}" ]]; then
            relevant_modules+=("$ecs_module")
        fi
    done
    echo "Relevant ECS modules: ${relevant_modules[*]}"
}

# Run the ECS generator script for relevant modules.
run_ecs_generator() {
    echo
    echo "---> Running ECS Generator script..."
    if [[ ${#relevant_modules[@]} -gt 0 ]]; then
        for ecs_module in "${relevant_modules[@]}"; do
            bash ecs/generator/mapping-generator.sh run "$ecs_module"
            echo "Processed ECS module: $ecs_module"
            bash ecs/generator/mapping-generator.sh down
        done
    else
        echo "No relevant modifications detected in ecs/ directory."
        exit 0
    fi
}

# Clone the target repository and set up GitHub authentication.
clone_target_repo() {
    # Clone the remote repository and change working directory to the
    # folder it was cloned to.
    echo
    echo "---> Cloning ${PLUGINS_REPO} repository..."
    if [ ! -d "$PLUGINS_LOCAL_PATH" ]; then
        git clone \
            https://"$GITHUB_TOKEN"@github.com/$PLUGINS_REPO.git \
            "$PLUGINS_LOCAL_PATH"
    fi
    cd "$PLUGINS_LOCAL_PATH" || exit

    # Only for the GH Workflow
    if check_running_on_gha; then
        echo "Configuring Git for ${COMMITTER_USERNAME}"
        configure_git
    fi
}

# Configure Git with the committer's identity and commit signing.
configure_git() {
    # Setup the committers identity.
    git config --global user.email "${COMMITER_EMAIL}"
    git config --global user.name "${COMMITTER_USERNAME}"

    # Store the SSH key pair so Git can read it.
    mkdir -p ~/.ssh/
    echo "${SSH_PRIVATE_KEY}" > ~/.ssh/id_ed25519_bot
    echo "${SSH_PUBLIC_KEY}" > ~/.ssh/id_ed25519_bot.pub
    chmod 600 ~/.ssh/id_ed25519_bot
    chmod 644 ~/.ssh/id_ed25519_bot.pub

    # Setup commit signing
    ssh-add ~/.ssh/id_ed25519_bot
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    git config --global user.signingkey ~/.ssh/id_ed25519_bot.pub
}

# Commit and push changes to the target repository.
commit_and_push_changes() {
    echo
    echo "---> Committing and pushing changes to ${PLUGINS_REPO} repository..."
    git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1
    EXIT_CODE=$?

    if [[ $EXIT_CODE == '0' ]]; then
        git checkout "$BRANCH_NAME"
        git pull origin "$BRANCH_NAME"
    else
        git checkout -b "$BRANCH_NAME"
        git push --set-upstream origin "$BRANCH_NAME"
    fi

    echo "Copying ECS templates to the plugins repository..."
    for ecs_module in "${relevant_modules[@]}"; do
        target_file=${module_to_file[$ecs_module]}
        if [[ -z "$target_file" ]]; then
            continue
        fi
        # Save the template on the output path
        mkdir -p "$OUTPUT_PATH"
        cp "$CURRENT_PATH/ecs/$ecs_module/$MAPPINGS_SUBPATH" "$OUTPUT_PATH/$target_file"
        # Copy the template to the plugins repository
        mkdir -p $TEMPLATES_PATH
        echo "  - Copy template for module '$ecs_module' to '$target_file'"
        cp "$CURRENT_PATH/ecs/$ecs_module/$MAPPINGS_SUBPATH" "$TEMPLATES_PATH/$target_file"
    done

    git status --short

    if ! git diff-index --quiet HEAD --; then
        echo "Changes detected. Committing and pushing to the repository..."
        git add .
        git commit -m "Update ECS templates for modified modules: ${relevant_modules[*]}"
        git push
    else
        echo "Nothing to commit, working tree clean."
        exit 0
    fi
}

# Create or update a Pull Request with the modified ECS templates.
create_or_update_pr() {
    echo
    echo "---> Creating or updating Pull Request..."

    local existing_pr
    local modules_body
    local title
    local body

    existing_pr=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[].number')
    # Format modules
    modules_body=$(printf -- '- %s\n' "${relevant_modules[@]}")

    # Create title and body with formatted modules list
    title="[ECS Generator] Update index templates"
    body=$(cat <<EOF
This PR updates the ECS templates for the following modules:
${modules_body}
EOF
)
    # Store the PAT in a file that can be accessed by the GitHub CLI.
    echo "${GITHUB_TOKEN}" > token.txt

    # Authorize GitHub CLI for the current repository and
    # create a pull-requests containing the updates.
    gh auth login --with-token < token.txt

    if [ -z "$existing_pr" ]; then
        output=$(gh pr create --title "$title" --body "$body" --base master --head "$BRANCH_NAME")
        pr_url=$(echo "$output" | grep -oP 'https://github.com/\S+')
        export PR_URL="$pr_url"
        echo "New pull request created: $PR_URL"
    else
        echo "PR already exists: $existing_pr. Updating the PR..."
        gh pr edit "$existing_pr" --body "$body"
        pr_url=$(gh pr view "$existing_pr" --json url -q '.url')
        export PR_URL="$pr_url"
        echo "Pull request updated: $PR_URL"
    fi

    # If the script is executed in a GHA, add a notice command.
    if check_running_on_gha; then
        echo "::notice::Pull Request URL:${PR_URL}"
    fi
}

# Display usage information.
usage() {
    echo "Usage: $0 -b <BRANCH_NAME> -t <GITHUB_TOKEN>"
    echo "  -t [GITHUB_TOKEN]   (Required) GitHub token to authenticate with GitHub API."
    echo "  -b [BRANCH_NAME]    (Optional) Branch name to create or update the PR. Default: current branch."
    echo "                      If not provided, the script will use the GITHUB_TOKEN environment variable."
    exit 1
}

# Main function
main() {
    while getopts ":b:t:o:" opt; do
        case ${opt} in
            b )
                BRANCH_NAME=$OPTARG
                ;;
            t )
                GITHUB_TOKEN=$OPTARG
                ;;
            o )
                if [[ "$OPTARG" == "./"* || ! "$OPTARG" =~ ^/ ]]; then
                    OPTARG="$(pwd)/${OPTARG#./}"
                fi
                OUTPUT_PATH=$OPTARG
                ;;
            \? )
                usage
                ;;
            : )
                echo "Invalid option: $OPTARG requires an argument" 1>&2
                usage
                ;;
        esac
    done

    if [ -z "$BRANCH_NAME" ]; then
        # Check if we are in a Git repository
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
        else
            echo "Error: You are not in a Git repository." >&2
            exit 1
        fi
    fi

    if [ -z "$BRANCH_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
        usage
    fi

    validate_dependencies
    detect_modified_modules
    run_ecs_generator # Exit if no changes on relevant modules.
    clone_target_repo
    commit_and_push_changes # Exit if no changes detected.
    create_or_update_pr
}

main "$@"
