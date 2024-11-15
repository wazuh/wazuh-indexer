# Testing environment

This is an environment definition with the required configuration to be prepared to freshly install a Wazuh Indexer
cluster with two nodes using Vagrant and Libvirt to provision the Virtual Machines.

It also generates the node's required certificates using the `wazuh-certs-tool` and copy them to each node's `/home`
directory, leaving a copy in `test-tools/`.

### Prerequisites

1. Download and install Vagrant ([source](https://developer.hashicorp.com/vagrant/downloads))
2. Install vagrant-libvirt ([source](https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html))
   > In some cases you must also install `libvirt-dev`

## Usage

1. Navigate to the environment's root directory
   ```bash
   cd test-tools
   ```
2. Initialize the environment
   ```bash
   vagrant up
   ```
3. Connect to the different systems
   ```bash
   vagrant ssh indexer_[1|2]
   ```

### Test scripts

Some scripts are included to easily validate the correct basic functionality of a wazuh-indexer package, these are also being copied in the node's `/home/scripts` directory. More info at [scripts/README.md](scripts/README.md)

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
