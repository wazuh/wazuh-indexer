# Wazuh Indexer packages generation guide

This guide includes instructions to generate distribution packages locally using Docker.

Wazuh Indexer supports any of these combinations:

- distributions: `['tar', 'deb', 'rpm']`
- architectures: `['x64', 'arm64']`

Windows is currently not supported.

The process to build packages requires Docker and Docker Compose.

- [Install Docker](https://docs.docker.com/engine/install/)
- [Install Docker Compose](https://docs.docker.com/compose/install/linux/)

Before you get started, make sure to clean your environment by running `./gradlew clean`.

## Building wazuh-indexer packages

Use the script under `wazuh-indexer/docker/builder/builder.sh` to build a package.

```bash
./builder.sh -h
Usage: ./builder.sh [args]

Arguments:
-p INDEXER_PLUGINS_BRANCH     [Optional] wazuh-indexer-plugins repo branch, default is 'master'.
-r INDEXER_REPORTING_BRANCH   [Optional] wazuh-indexer-reporting repo branch, default is 'master'.
-R REVISION                   [Optional] Package revision, default is '0'.
-s STAGE                      [Optional] Staging build, default is 'false'.
-d DISTRIBUTION               [Optional] Distribution, default is 'rpm'.
-a ARCHITECTURE               [Optional] Architecture, default is 'x64'.
-D      Destroy the docker environment
-h      Print help
```

The resulting package will be stored at `wazuh-indexer/artifacts/dist`.

> The `STAGE` option defines the naming of the package. When set to `false`, the package will be unequivocally named with the commits' SHA of the `wazuh-indexer`, `wazuh-indexer-plugins` and `wazuh-indexer-reporting` repositories, in that order. For example: `wazuh-indexer_5.0.0-0_x86_64_aff30960363-846f143-494d125.rpm`.

## Building wazuh-indexer docker images

> TBD. For manual building refer to [our Docker containers guide](../docker/README.md).
