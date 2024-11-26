# Docker environments

Multipurpose Docker environments to run, test and build `wazuh-indexer`.

## Pre-requisites

1. Install [Docker][docker] as per its instructions.

1. Your workstation must meet the minimum hardware requirements:

   - 8 GB of RAM (minimum)
   - 4 cores

   The more resources the better ☺

1. Clone the [wazuh-indexer][wi-repo].

## Development environments

Use the `dev/dev.sh` script to start a development environment.

Example:

```bash
Usage: ./dev.sh {up|down|stop}
```

Once the `wi-dev:x.y.z` container is up, attach a shell to it and run `./gradlew run` to start the application.

## Containers to generate packages

The `builder` image automates the build and assemble process for the Wazuh Indexer and its plugins, making it easy to create packages on any system.

### Usage
1. Build the image:
    ```bash
    cd docker/builder && docker build -t wazuh-indexer-builder .
    ```
2. Execute the package building process
    ```bash
    docker run --rm -v /path/to/local/artifacts:/artifacts wazuh-indexer-builder
    ```
    > Replace `/path/to/local/artifacts` with the actual path on your host system where you want to store the resulting package.

#### Environment Variables
You can customize the build process by setting the following environment variables:

- `INDEXER_BRANCH`: The branch to use for the Wazuh Indexer (default: `master`).
- `INDEXER_PLUGINS_BRANCH`: The branch to use for the Wazuh Indexer plugins (default: `master`).
- `INDEXER_REPORTING_BRANCH`: The branch to use for the Wazuh Indexer reporting (default: `master`).
- `REVISION`: The revision number for the build (default: `0`).
- `IS_STAGE`: Whether the build is a staging build (default: `false`).
- `DISTRIBUTION`: The distribution format for the package (default: `tar`).
- `ARCHITECTURE`: The architecture for the package (default: `x64`).

Example usage with custom environment variables:
```sh
docker run --rm -e INDEXER_BRANCH="5.0.0" -e INDEXER_PLUGINS_BRANCH="5.0.0" -e INDEXER_REPORTING_BRANCH="5.0.0" -v /path/to/local/artifacts:/artifacts wazuh-indexer-builder
```

Refer to [build-scripts/README.md](../build-scripts/README.md) for details about how to build packages.

[docker]: https://docs.docker.com/engine/install
[wi-repo]: https://github.com/wazuh/wazuh-indexer

## Building Docker images

The [prod](./prod) folder contains the code to build Docker images. A tarball of `wazuh-indexer` needs to be located at the same level that the Dockerfile. Below there is an example of the command needed to build the image. Set the build arguments and the image tag accordingly.

```console
docker build --build-arg="VERSION=5.0.0" --build-arg="INDEXER_TAR_NAME=wazuh-indexer-5.0.0-1_linux-x64_cfca84f.tar.gz" --tag=wazuh-indexer:5.0.0 --progress=plain --no-cache .
```

Then, start a container with:

```console
docker run -it --rm wazuh-indexer:5.0.0
```
