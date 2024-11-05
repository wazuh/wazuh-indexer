# How to Build `wazuh-indexer` DEB and RPM Packages

> [!CAUTION]
>
> Be aware that there might be some problems while following the steps in this guide due to outdated information.
> This document is pending a review. Let us know if you find any issues.

The packages' generation process consists on 2 steps:

- **Build**: compiles the Java application and bundles it into a package.
- **Assembly**: uses the package from the previous step and inflates it with plugins and
  configuration files, ready for production deployment.

We usually generate the packages using GitHub Actions, however, the process is designed to
be independent enough for maximum portability. GitHub Actions provides infrastructure, while
the building process is self-contained in the application code.

Each section includes instructions to generate packages locally, using Act or Docker.

- [Install Act](https://github.com/nektos/act)

The names of the packages are managed by the `baptizer.sh` script.

## Building the plugins

Follow the [DEVELOPER_GUIDE.md](https://github.com/wazuh/wazuh-indexer-plugins/blob/master/DEVELOPER_GUIDE.md) instructions to build the plugins. The build scripts expect the plugins in the Maven local repository or under the `artifacts/plugins` folder.

1. Build the plugins.
2. Publish the plugins to the local Maven repository: run `./gradlew publishToMavenLocal`.
    - Alternatively, copy the generated zip files to the `artifacts/plugins` folder.
3. Build and Assemble the `wazuh-indexer` package.

## Build and Assemble in Act

Use Act to run the `build.yml` workflow locally. The `act.input.env` file contains the inputs
for the workflow. As the workflow clones the `wazuh-indexer-plugins` repository, the `GITHUB_TOKEN`
is required. You can use the `gh` CLI to authenticate, as seen in the example below.

```console
act -j build -W .github/workflows/build.yml --artifact-server-path ./artifacts --input-file build-scripts/act.input.env -s GITHUB_TOKEN="$(gh auth token)"
```

## Build

For local package generation, use the `build.sh` script. Take a look at the `build.yml`
workflow file for an example of usage.

```bash
bash build-scripts/build.sh -a x64 -d tar -n $(bash build-scripts/baptizer.sh -a x64 -d tar -m)
```

#### Act (GitHub Workflow locally)

```console
act -j build -W .github/workflows/build.yml --artifact-server-path ./artifacts

[Build slim packages/build] 🏁  Job succeeded
```

#### Running in Docker

Using the [Docker environment](../docker):

```console
docker exec -it wi-build_$(<VERSION) bash build-scripts/build.sh -a x64 -d tar -n $(bash build-scripts/baptizer.sh -a x64 -d tar -m)
```

The generated package is sent to the `wazuh-indexer/artifacts` folder.

## Assemble

**Note:** set the environment variable `TEST=true` to assemble a package with the required plugins only,
speeding up the assembly process.

### TAR

The assembly process for tarballs consists on:

1. Extract.
2. Install plugins.
3. Add Wazuh's configuration files and tools.
4. Compress.

```console
bash build-scripts/assemble.sh -a x64 -d tar -r 1
```

### DEB

For DEB packages, the `assemble.sh` script will perform the following operations:

1. Extract the deb package using `ar` and `tar` tools.

   > By default, `ar` and `tar` tools expect the package to be in `wazuh-indexer/artifacts/tmp/deb`.
   > The script takes care of creating the required folder structure, copying also the min package
   > and the Makefile.

   Current folder loadout at this stage:

   ```
   artifacts/
   |-- dist
   |   |-- wazuh-indexer-min_5.0.0_amd64.deb
   `-- tmp
       `-- deb
           |-- Makefile
           |-- data.tar.gz
           |-- debmake_install.sh
           |-- etc
           |-- usr
           |-- var
           `-- wazuh-indexer-min_5.0.0_amd64.deb
   ```

   `usr`, `etc` and `var` folders contain `wazuh-indexer` files, extracted from `wazuh-indexer-min-*.deb`.
   `Makefile` and the `debmake_install` are copied over from `wazuh-indexer/distribution/packages/src/deb`.
   The `wazuh-indexer-performance-analyzer.service` file is also copied from the same folder. It is a dependency of the SPEC file.

2. Install the plugins using the `opensearch-plugin` CLI tool.
3. Set up configuration files.

   > Included in `min-package`. Default files are overwritten.

4. Bundle a DEB file with `debmake` and the `Makefile`.

   > `debmake` and other dependencies can be installed using the `provision.sh` script.
   > The script is invoked by the GitHub Workflow.

   Current folder loadout at this stage:

   ```
   artifacts/
   |-- artifact_name.txt
   |-- dist
   |   |-- wazuh-indexer-min_5.0.0_amd64.deb
   |   `-- wazuh-indexer_5.0.0_amd64.deb
   `-- tmp
       `-- deb
           |-- Makefile
           |-- data.tar.gz
           |-- debmake_install.sh
           |-- etc
           |-- usr
           |-- var
           |-- wazuh-indexer-min_5.0.0_amd64.deb
           `-- debian/
               | -- control
               | -- copyright
               | -- rules
               | -- preinst
               | -- prerm
               | -- postinst
   ```

#### Running in Docker

Pre-requisites:

- Current directory: `wazuh-indexer/`
- Existing deb package in `wazuh-indexer/artifacts/dist/deb`, as a result of the _Build_ stage.
- Using the [Docker environment](../docker):

```console
docker exec -it wi-assemble_$(<VERSION) bash build-scripts/assemble.sh -a x64 -d deb -r 1
```

### RPM

The `assemble.sh` script will use the output from the `build.sh` script and use it as a
base to bundle together a final package containing the plugins, the production configuration
and the service files.

The script will:

1. Extract the RPM package using `rpm2cpio` and `cpio` tools.

   > By default, `rpm2cpio` and `cpio` tools expect the package to be in `wazuh-indexer/artifacts/tmp/rpm`. The script takes care of creating the required folder structure, copying also the min package and the SPEC file.

   Current folder loadout at this stage:

   ```
   /rpm/$ARCH
       /etc
       /usr
       /var
       wazuh-indexer-min-*.rpm
       wazuh-indexer.rpm.spec
   ```

   `usr`, `etc` and `var` folders contain `wazuh-indexer` files, extracted from `wazuh-indexer-min-*.rpm`.
   `wazuh-indexer.rpm.spec` is copied over from `wazuh-indexer/distribution/packages/src/rpm/wazuh-indexer.rpm.spec`.
   The `wazuh-indexer-performance-analyzer.service` file is also copied from the same folder. It is a dependency of the SPEC file.

2. Install the plugins using the `opensearch-plugin` CLI tool.
3. Set up configuration files.

   > Included in `min-package`. Default files are overwritten.

4. Bundle an RPM file with `rpmbuild` and the SPEC file `wazuh-indexer.rpm.spec`.

   > `rpmbuild` is part of the `rpm` OS package.

   > `rpmbuild` is invoked from `wazuh-indexer/artifacts/tmp/rpm`. It creates the {BUILD,RPMS,SOURCES,SRPMS,SPECS,TMP} folders and applies the rules in the SPEC file. If successful, `rpmbuild` will generate the package in the `RPMS/` folder. The script will copy it to `wazuh-indexer/artifacts/dist` and clean: remove the `tmp\` folder and its contents.

   Current folder loadout at this stage:

   ```
   /rpm/$ARCH
       /{BUILD,RPMS,SOURCES,SRPMS,SPECS,TMP}
       /etc
       /usr
       /var
       wazuh-indexer-min-*.rpm
       wazuh-indexer.rpm.spec
   ```

#### Running in Docker

Pre-requisites:

- Current directory: `wazuh-indexer/`
- Existing rpm package in `wazuh-indexer/artifacts/dist/rpm`, as a result of the _Build_ stage.
- Using the [Docker environment](../docker):

```console
docker exec -it wi-assemble_$(<VERSION) bash build-scripts/assemble.sh -a x64 -d rpm -r 1
```

## Bash scripts reference

The packages' generation process is guided through bash scripts. This section list and describes
them, as well as their inputs and outputs.

```yml
scripts:
  - file: build.sh
    description: |
      generates a distribution package by running the appropiate Gradle task
      depending on the parameters.
    inputs:
      architecture: [x64, arm64] # Note: we only build x86_64 packages
      distribution: [tar, deb, rpm]
      name: the name of the package to be generated.
    outputs:
      package: minimal wazuh-indexer package for the required distribution.

  - file: assemble.sh
    description: |
      bundles the wazuh-indexer package generated in by build.sh with plugins,
      configuration files and demo certificates (certificates yet to come).
    inputs:
      architecture: [x64, arm64] # Note: we only build x86_64 packages
      distribution: [tar, deb, rpm]
      revision: revision number. 0 by default.
    outputs:
      package: wazuh-indexer package.

  - file: provision.sh
    description: Provision script for the assembly of DEB packages.

  - file: baptizer.sh
    description: generate the wazuh-indexer package name depending on the parameters.
    inputs:
      architecture: [x64, arm64] # Note: we only build x86_64 packages
      distribution: [tar, deb, rpm]
      revision: revision number. 0 by default.
      plugins_hash: Commit hash of the `wazuh-indexer-plugins` repository.
      reporting_hash: Commit hash of the `wazuh-indexer-reporting` repository.
      is_release: if set, uses release naming convention.
      is_min: if set, the package name will start by `wazuh-indexer-min`. Used on the build stage.
    outputs:
      package: the name of the wazuh-indexer package.
```
