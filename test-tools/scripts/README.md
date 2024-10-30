# Test utils scripts

This is a collection of scripts aimed to facilitate the validation of the wazuh-indexer packages generated on GHA.

Even if these scripts can be executed in almost any Linux environment, we expect it to be used alongside the
Vagrant environment defined in the `test-tools`, using the scripts inside the VMs to facilitate the validation steps.

## GitHub token requirements

Create a personal access token for GitHub with at least `read:packages` permissions.

### Validation flow

Run all tests at once:

```console
sudo bash 00_run.sh
```

If you prefer, you can run each script individually.

1. Check the artifact was created and package can be downloaded and installed (run on each node)
   ```bash
    GITHUB_TOKEN=<GH_TOKEN> bash 01_download_and_install_package.sh -id <RUN_ID> -n <PACKAGE_NAME>
    ```
2. Check the service can be started`
   ```bash
    bash 02_apply_certificates.sh -p <PATH_TO_CERTS.TAR> -n <NAME_NODE_1> -nip <IP_NODE_1> [-s <NAME_NODE_2> -sip <IP_NODE_2>]
    ```
    ```bash
    bash 03_manage_indexer_service.sh -a start
    ```
    > You can also test `restart` and `stop`
3. Check the cluster can be initialized
    ```bash
    bash 04_initialize_cluster.sh 
    ```
4. Check all the plugins are installed
    ```bash
    bash 05_validate_installed_plugins.sh -n <NODE_1_NAME> [-n <NODE_2_NAME>]
    ```
5. Check the setup plugin configured the index-patterns correctly
    ```bash
    bash 06_validate_setup.sh
    ```
6. Check the command manager plugin works correctly
    ```bash
    bash 07_validate_command_manager.sh
    ```
7. Check wazuh-indexer can be uninstalled
    ```bash
    bash 08_uninstall_indexer.sh
    ```

