# Cross Cluster Search (CCS) environment
This environment enables the deployment of a Wazuh Indexer cluster with Cross Cluster Search configuration, using Vagrant and Virtualbox (or other supported providers).

It also generates the node's required certificates using the `wazuh-certs-tool` and copy them to each node's `/home/vagrant`
directory, leaving a copy in `tools/ccs`.

For the development of this environment, we have based it on [Wazuh documentation](https://wazuh.com/blog/managing-multiple-wazuh-clusters-with-cross-cluster-search/)

### Prerequisites

1. Download and install Vagrant ([source](https://developer.hashicorp.com/vagrant/downloads))
2. Install virtualbox ([source](https://www.virtualbox.org/wiki/Downloads))

> [!Note]
> If instead of virtualbox you want to use another provider like libvirt, the variable on the second line of the Vagrantfile should be changed to the name of the desired provider.

## Wazuh Version Configuration

The Wazuh version is set in the first line of the `Vagrantfile` within the variable `version`. You can change it to your desired version, for example:

```
version = "4.12.0"
```

This version is passed to the `node-start.sh` script during provisioning.

## Infrastructure Overview
The environment includes the following nodes:

- ccs: Main control node (Cross Cluster Search)
- cluster_a: Cluster A node
- cluster_b: Cluster B node

Each node is configured with its IP address, hostname, and system resources (RAM, CPUs).

## Requirements:
| Node      | RAM      | CPU        |
|-----------|----------|------------|
| ccs       | 4 GB     | 4 cores    |
| cluster_a | 4 GB     | 4 cores    |
| cluster_b | 4 GB     | 4 cores    |


## Usage

1. Navigate to the environment's root directory
   ```bash
   cd tools
   ```
2. Initialize the environment
   ```bash
   vagrant up
   ```

> [!Note]
> The process of starting all the nodes and configuring them may take approximately 20 minutes.


3. Connect to the different systems
   ```bash
   vagrant ssh ccs/cluster_a/cluster_b
   ```


### Cleanup

After the testing session is complete you can stop or destroy the environment as you wish:

- Stop the environment:
  ```bash
  vagrant halt
  ```
- Destroy the environment:
  ```bash
  vagrant destroy -f
  ```
