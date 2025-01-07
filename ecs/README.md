## ECS mappings generator

This script generates the ECS mappings for the Wazuh indices.

### Requirements

- [Docker Compose](https://docs.docker.com/compose/install/)

### Folder structure

There is a folder for each module. Inside each folder, there is a `fields` folder with the required files to generate the mappings. These are the inputs for the ECS generator.

### Usage

1. Execute the mapping-generator tool
    ```bash
    bash ecs/generator/mapping-generator.sh run <MODULE_NAME>
    ```
2. (Optional) Run the tool's cleanup
    > The tool stops the container automatically, but it is recommended to run the down command if the tool is not going to be used anymore.
    ```bash
    bash ecs/generator/mapping-generator.sh down
    ```

### Output

A new `mappings` folder will be created inside the module folder, containing all the generated files.
The files are versioned using the ECS version, so different versions of the same module can be generated.
For our use case, the most important files are under `mappings/<ECS_VERSION>/generated/elasticsearch/legacy/`:

- `template.json`: Elasticsearch compatible index template for the module
- `opensearch-template.json`: OpenSearch compatible index template for the module

The original output is `template.json`, which is not compatible with OpenSearch by default.
In order to make this template compatible with OpenSearch, the following changes are made:

- The `order` property is renamed to `priority`.
- The `mappings` and `settings` properties are nested under the `template` property.

The script takes care of these changes automatically, generating the `opensearch-template.json` file as a result.

### Upload

You can either upload the index template using cURL or the UI (dev tools).

```bash
curl -u admin:admin -k -X PUT "https://indexer:9200/_index_template/wazuh-states-vulnerabilities" -H "Content-Type: application/json" -d @opensearch-template.json
```

Notes:
- PUT and POST are interchangeable.
- The name of the index template does not matter. Any name can be used.
- Adjust credentials and URL accordingly.

### Adding new mappings

The easiest way to create mappings for a new module is to take a previous one as a base.
Copy a folder and rename it to the new module name. Then, edit the `fields` files to match the new module fields.

The name of the folder will be the name of the module to be passed to the script. All 3 files are required.

- `fields/subset.yml`: This file contains the subset of ECS fields to be used for the module.
- `fields/template-settings-legacy.json`: This file contains the legacy template settings for the module.
- `fields/template-settings.json`: This file contains the composable template settings for the module.

### Event generator

Each module contains a Python script to generate events for its module. The script prompts for the required parameters, so it can be launched without arguments:
  
```bash
./event_generator.py
```

The script will generate a JSON file with the events, and will also ask whether to upload them to the indexer. If the upload option is selected, the script will ask for the indexer URL and port, credentials, and index name.
The script uses log file. Check it out for debugging or additional information.

---

### Automatic PR creation tool

The `generate-pr-to-plugins.sh` script found in the `ecs/scripts` folder is a tool that detects modified ECS modules, generates new templates, commits the changes to a target repository, and creates or updates a pull request.

#### Requirements

- Docker Compose
- GitHub CLI (`gh`)

#### Usage

To use the script, run the following command:

```sh
./update-ecs-templates.sh -t <GITHUB_TOKEN>
```

**Options**

- `-b <BRANCH_NAME>`: (Optional) Branch name to create or update the pull request. Default is current branch.
- `-t <GITHUB_TOKEN>`: (Optional) GitHub token to authenticate with the GitHub API. If not provided, the script will use the `GITHUB_TOKEN` environment variable.

#### Script Workflow

1. **Validate Dependencies**
   - Checks if the required commands (`docker`, `docker-compose`, and `gh`) are installed.

2. **Detect Modified Modules**
   - Fetches and extracts modified ECS modules by comparing the current branch with the base branch.
   - Identifies relevant ECS modules that have been modified.

3. **Run ECS Generator**
   - Runs the ECS generator script for each relevant module to generate new ECS templates.

4. **Clone Target Repository**
   - Clones the target repository (`wazuh/wazuh-indexer-plugins`) if it does not already exist.
   - Configures Git and GitHub CLI with the provided GitHub token.

5. **Commit and Push Changes**
   - Copies the generated ECS templates to the appropriate directory in the target repository.
   - Commits and pushes the changes to the specified branch.

6. **Create or Update Pull Request**
   - Creates a new pull request or updates an existing pull request with the modified ECS templates.

#### References

- [ECS repository](https://github.com/elastic/ecs)
- [ECS usage](https://github.com/elastic/ecs/blob/main/USAGE.md)
- [ECS field reference](https://www.elastic.co/guide/en/ecs/current/ecs-field-reference.html)
