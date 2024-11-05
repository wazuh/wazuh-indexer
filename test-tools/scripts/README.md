# Test utils scripts

This is a collection of scripts aimed to facilitate the validation of the wazuh-indexer packages generated on the GitHub Action Workflow.

Even if these scripts can be executed in almost any Linux environment, we expect it to be used alongside the
Vagrant environment defined in the `test-tools`, using the scripts inside the VMs to facilitate the validation steps.

### GitHub token requirements

Create a personal access token for GitHub with at least `read:packages` permissions.

## Validation flow

The scripts can be used to prepare and validate a single node or multi-node cluster, as required.

### All-at-once

#### Single node

Use the `00_run.sh` utility to execute all the scripts automatically
```bash
sudo bash 00_run.sh
```

#### Multi node cluster

> This section assumes you are using the `node-1` and `node-2` Vagrant VMs

1. On the `node-2` VM install and prepare the `wazuh-indexer` component
   ```bash
    GITHUB_TOKEN=<GH_TOKEN> bash 01_download_and_install_package.sh -id <RUN_ID> -n <PACKAGE_NAME>
   ```
   ```bash
    sudo bash 02_apply_certificates.sh -p ../wazuh-certificates.tar -n node-2 -nip 192.168.56.11 -s node-1 -sip 192.168.56.10
    ```
    ```bash
    sudo bash 03_manage_indexer_service.sh -a start
    ```
2. On the `node-1` VM execute the _all-at-once_ utility
    ```bash
    sudo bash 00_run.sh
    ```

### Manual execution

If you prefer, you can run each script individually.

1. Download and install the `wazuh-indexer` package _(mandatory on each node)_
   ```bash
    GITHUB_TOKEN=<GH_TOKEN> bash 01_download_and_install_package.sh -id <RUN_ID> -n <PACKAGE_NAME>
    ```
2. Configure and start the service _(mandatory on each node)_
   ```bash
    sudo bash 02_apply_certificates.sh -p <PATH_TO_CERTS.TAR> -n <NODE_NAME> -nip <NODE_IP>
    ```
    ```bash
    sudo bash 03_manage_indexer_service.sh -a start
    ```
    > With this script you can also `restart` and `stop` the service
3. Initialize the cluster
    ```bash
    sudo bash 04_initialize_cluster.sh
    ```
4. Check all the plugins are installed
    ```bash
    bash 05_validate_installed_plugins.sh -n <NODE_NAME>
    ```
5. Check the setup plugin configured the index-patterns correctly
    ```bash
    bash 06_validate_setup.sh
    ```
6. Check the command manager plugin works correctly
    ```bash
    bash 07_validate_command_manager.sh
    ```
7. Uninstall Wazuh indexer
    ```bash
    sudo bash 08_uninstall_indexer.sh
    ```
