# Cross Cluster Search (CCS) environment

This environment deploys three Wazuh 5.x clusters with Vagrant and connects them through
Cross Cluster Search: a CCS node running the Wazuh indexer and the Wazuh dashboard, and two remote
clusters, A and B, each running the Wazuh indexer and the Wazuh server. From the CCS node you can
search the data of both remote clusters and manage both Wazuh servers from one dashboard.

It works with VirtualBox and with libvirt.

### Prerequisites

1. Download and install Vagrant ([source](https://developer.hashicorp.com/vagrant/downloads))
2. Install a provider:
   - VirtualBox ([source](https://www.virtualbox.org/wiki/Downloads)), or
   - libvirt with the [vagrant-libvirt](https://vagrant-libvirt.github.io/vagrant-libvirt/) plugin.
3. Install OpenSSL on the host. It is used to create the root CA of the environment.

## Infrastructure overview

| Node      | IP address    | Host name   | Components                               | RAM  | CPU     |
| --------- | ------------- | ----------- | ---------------------------------------- | ---- | ------- |
| ccs       | 192.168.56.10 | `ccs`       | Wazuh indexer (`ccs-cluster`), dashboard | 4 GB | 4 cores |
| cluster_a | 192.168.56.11 | `cluster-a` | Wazuh indexer (`ca-cluster`), server     | 4 GB | 4 cores |
| cluster_b | 192.168.56.12 | `cluster-b` | Wazuh indexer (`cb-cluster`), server     | 4 GB | 4 cores |

The CCS node registers the remote clusters as `ca-wazuh-indexer-1` and `cb-wazuh-indexer-1`, and
the dashboard connects to the Wazuh server API of both, as `cluster-a` and `cluster-b`.

## Configuration

The `Vagrantfile` reads these environment variables:

| Variable              | Default                                                                                                   | Description                                    |
| --------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `WAZUH_ARTIFACT_URLS` | `https://packages-staging.xdrsiem.wazuh.info/nightly/5.0.0/artifact-urls/artifact_urls_5.0.0-latest.yaml` | Artifact list the RPM packages are taken from. |
| `VM_MEMORY`           | `4096`                                                                                                    | RAM of each node, in MB.                       |
| `VM_CPUS`             | `4`                                                                                                       | CPUs of each node.                             |

By default, the environment installs the latest 5.0.0 nightly packages. To test another build,
point `WAZUH_ARTIFACT_URLS` to its artifact list.

### Certificates and credentials

The Wazuh 5.x packages issue their own certificates and generate their own passwords when
installed. Before the nodes are created, `pre-start.sh` prepares the two things they must share:

- **`ca/root-ca.pem` and `ca/root-ca.key`**: the root CA every node issues its certificates from.
  The clusters must share it to trust each other.
- **`credentials.env`**: the passwords given to the packages instead of generating them.
  `pre-start.sh` only puts `WAZUH_MANAGER_WUI_PASSWORD` in it, because the dashboard on the CCS
  node needs it to connect to both Wazuh servers. Every other password is generated on each node.

Both are copied to `/etc/wazuh/` on every node and kept between runs. To use your own CA or
passwords, create them in `tools/ccs` before running `vagrant up`. If your `credentials.env` has no
`WAZUH_MANAGER_WUI_PASSWORD`, a generated one is added to it. For example:

```
WAZUH_MANAGER_WUI_PASSWORD=<password>
WAZUH_INDEXER_ADMIN_PASSWORD=<password>
```

Passwords must be 12 to 64 characters long, use only `A-Z a-z 0-9 . , _ + : @ % ^ = ~ -`, and
include at least one uppercase letter, one lowercase letter, one digit and one symbol.

The passwords used on each node, generated or not, are in its `/etc/wazuh/credentials.env`.

## Usage

1. Navigate to the environment's root directory
   ```bash
   cd tools/ccs
   ```
2. Initialize the environment
   ```bash
   vagrant up
   ```

> [!Note]
> With libvirt, the three nodes are provisioned in parallel. Each one downloads its packages from
> the artifact list, which can take a while.

3. Connect to the different systems
   ```bash
   vagrant ssh ccs/cluster_a/cluster_b
   ```

## Test the Cross Cluster Search

1. Get the password of the `admin` user of the CCS node:
   ```bash
   vagrant ssh ccs -c "sudo grep ^WAZUH_INDEXER_ADMIN_PASSWORD= /etc/wazuh/credentials.env"
   ```

2. Log in to the Wazuh dashboard:
   ```
   URL: https://192.168.56.10
   Username: admin
   Password: <the password from the previous step>
   ```

   The browser warns about the certificate, because it is issued by the CA of the environment. To
   avoid it, trust `tools/ccs/ca/root-ca.pem` in your browser.

3. Open **Dev Tools** (`https://192.168.56.10/app/dev_tools#/console`) and check that both remote
   clusters are connected:
   ```
   GET _remote/info
   ```
   ```json
   {
     "ca-wazuh-indexer-1": {
       "connected": true,
       "mode": "sniff",
       "seeds": ["192.168.56.11:9300"],
       "num_nodes_connected": 1,
       ...
     },
     "cb-wazuh-indexer-1": {
       "connected": true,
       ...
     }
   }
   ```

4. Run a search on both remote clusters. Until agents report to the Wazuh servers, there are no
   events, but the servers' own metrics are a good test:
   ```
   GET *:wazuh-metrics-*/_search
   ```
   ```json
   {
     "took": 56,
     "timed_out": false,
     "num_reduce_phases": 3,
     "_shards": {
       "total": 6,
       "successful": 6,
       "skipped": 0,
       "failed": 0
     },
     "_clusters": {
       "total": 2,
       "successful": 2,
       "skipped": 0
     },
     "hits": {
       "total": {
         "value": 40,
         "relation": "eq"
       },
       "max_score": 1,
       "hits": [
         {
           "_index": "cb-wazuh-indexer-1:.ds-wazuh-metrics-comms-v4-000001",
           ...
   ```

   `*` matches both remote clusters. Use a remote cluster name to search only one, for example
   `ca-wazuh-indexer-1:wazuh-events-v5*` for the events of cluster A.

The dashboard also connects to the Wazuh server API of both remote clusters, listed in its API
connections as `cluster-a` and `cluster-b`.

### Explore the remote data in the dashboard

1. Open **Dashboards Management** > **Index patterns**
   (`https://192.168.56.10/app/management/opensearch-dashboards/indexPatterns`) and select
   **Create index pattern**.
2. Enter an index pattern with the `<cluster>:<index>` format, for example `*:wazuh-events-v5*` for
   the events of both remote clusters. Select **Next step**.
3. Select **@timestamp** as the time field and select **Create index pattern**.
4. Open **Discover** and select the new index pattern.

## Cleanup

After the testing session is complete you can stop or destroy the environment as you wish:

- Stop the environment:
  ```bash
  vagrant halt
  ```
- Destroy the environment:
  ```bash
  vagrant destroy -f
  ```

To start the next environment with a new CA and new passwords, also delete `ca/` and
`credentials.env`.
