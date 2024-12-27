# Docker environments

Multipurpose Docker environments to run, test and build `wazuh-indexer`.

## Pre-requisites

1. Install [Docker][docker] as per its instructions.

2. Your workstation must meet the minimum hardware requirements:

   - 8 GB of RAM (minimum)
   - 4 cores

   The more resources the better ☺

3. Clone the [wazuh-indexer][wi-repo].

## Development environments

Use the `dev/dev.sh` script to start a development environment.

Example:

```bash
Usage: ./dev.sh {up|down|stop}
```

Once the `wi-dev:x.y.z` container is up, attach a shell to it and run `./gradlew run` to start the application.

## Containers to generate packages

The `builder` image automates the build and assemble process for the Wazuh Indexer and its plugins, making it easy to create packages on any system.

In the example below, it will generate a wazuh-indexer package for Debian based systems, for the x64 architecture, using 1 as revision number and using the production naming convention.

```bash
# Wihtin wazu-indexer/docker/builder
bash builder.sh -d deb -a x64 -R 1 -s true
```

Refer to [build-scripts/README.md](../build-scripts/README.md) for details about how to build packages.

## Building Docker images

The [prod](./prod) folder contains the code to build Docker images. A tarball of `wazuh-indexer` needs to be located at the same level that the Dockerfile. Below there is an example of the command needed to build the image. Set the build arguments and the image tag accordingly.

```bash
docker build --build-arg="VERSION=5.0.0" --build-arg="INDEXER_TAR_NAME=wazuh-indexer_5.0.0-0_linux-x64.tar.gz" --tag=wazuh-indexer:5.0.0-0 --progress=plain --no-cache .
```

Then, start a container with:

```bash
docker run -p 9200:9200 -it --rm quay.io/wazuh/wazuh-indexer:5.0.0-latest
```

Refer to [build-scripts/README.md](../build-scripts/README.md) for details about how to build and push Wazuh Indexer Docker images.

<!-- Links -->

[docker]: https://docs.docker.com/engine/install
[wi-repo]: https://github.com/wazuh/wazuh-indexer
