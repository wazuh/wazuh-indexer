# Test utils scripts

This is a collection of scripts aimed to facilitate the validation of the wazuh-indexer packages generated on GHA.

Even if these scripts can be executed in almost any Linux environment, we expect it to be used alongside the
Vagrant environment defined in the `test-tools`

### Validation flow

1. Check the package artifact is generated (run on each node)
    ```bash
    GITHUB_TOKEN=<GH_TOKEN> bash 00_search_package_artifact.sh -id <RUN_ID> -n <PACKAGE_NAME>
    ...
    [ Artifact ID: <ARTIFACT_ID> ]
    ```
2. Check package can be downloaded and installed (run on each node)
   > Use the ARTIFACT_ID obtained in the previous step
   ```bash
    GITHUB_TOKEN=<GH_TOKEN> bash 01_download_and_install_package.sh -id <ARTIFACT_ID> -n <PACKAGE_NAME>
    ```
3. Check the service can be started`
   ```bash
    bash 02_apply_certificates.sh -p <PATH_TO_CERTS.TAR> -c <CURRENT_NODE_NAME> -cip <NODE_IP> -s <OTHER_NODE_NAME> -sip <OTHER_NODE_IP>
    ```
    ```bash
    bash 03_manage_indexer_service.sh -a start
    ```
    > You can also test `restart` and `stop`
4. Check the cluster can be initialized
    ```bash
    bash 04_initialize_cluster.sh -ip <CLUSTER_IP>
    ```
5. Check all the plugins are installed
    ```bash
    bash 05_validate_installed_plugins.sh -ip <CLUSTER_IP> -n <NODE_1_NAME> -n <NODE_2_NAME>
    ```
6. Check the setup plugin configured the index-patterns correctly
    ```bash
    bash 06_validate_setup.sh -ip <CLUSTER_IP>
    ```
7. Check the command manager plugin works correctly
    ```bash
    bash 07_validate_command_manager.sh -ip<CLUSTER_IP>
    ```
8. Check wazuh-indexer can be uninstalled
    ```bash
    bash 08_uninstall_indexer.sh
    ```

