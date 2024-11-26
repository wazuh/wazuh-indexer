#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Print commands and their arguments as they are executed.
set -x

# Set default values for environment variables
INDEXER_BRANCH=${INDEXER_BRANCH:-master}
INDEXER_PLUGINS_BRANCH=${INDEXER_PLUGINS_BRANCH:-master}
INDEXER_REPORTING_BRANCH=${INDEXER_REPORTING_BRANCH:-master}
REVISION=${REVISION:-0}
IS_STAGE=${IS_STAGE:-false}
DISTRIBUTION=${DISTRIBUTION:-tar}
ARCHITECTURE=${ARCHITECTURE:-x64}

# Clone the repositories
git clone --branch "$INDEXER_BRANCH" https://github.com/wazuh/wazuh-indexer --depth 1 /home/indexer/wazuh-indexer
git clone --branch "$INDEXER_PLUGINS_BRANCH" https://github.com/wazuh/wazuh-indexer-plugins --depth 1 /home/indexer/wazuh-indexer-plugins
git clone --branch "$INDEXER_REPORTING_BRANCH" https://github.com/wazuh/wazuh-indexer-reporting --depth 1 /home/indexer/wazuh-indexer-reporting

# Set version env var
VERSION=$(cat /home/indexer/wazuh-indexer/VERSION)

# Build plugins
cd /home/indexer/wazuh-indexer-plugins/plugins/setup && ./gradlew build -Dversion="$VERSION" -Drevision="$REVISION" --no-daemon
cd /home/indexer/wazuh-indexer-plugins/plugins/command-manager && ./gradlew build -Dversion="$VERSION" -Drevision="$REVISION" --no-daemon

# Build reporting
cd /home/indexer/wazuh-indexer-reporting && ./gradlew build -Dversion="$VERSION" -Drevision="$REVISION" --no-daemon

# Copy builds
mkdir -p /home/indexer/wazuh-indexer/artifacts/plugins
cp /home/indexer/wazuh-indexer-plugins/plugins/setup/build/distributions/wazuh-indexer-setup-"$VERSION"."$REVISION".zip /home/indexer/wazuh-indexer/artifacts/plugins
cp /home/indexer/wazuh-indexer-plugins/plugins/command-manager/build/distributions/wazuh-indexer-command-manager-"$VERSION"."$REVISION".zip /home/indexer/wazuh-indexer/artifacts/plugins
cp /home/indexer/wazuh-indexer-reporting/build/distributions/wazuh-indexer-reports-scheduler-"$VERSION"."$REVISION".zip /home/indexer/wazuh-indexer/artifacts/plugins

# Combined RUN command for packaging
PLUGINS_HASH=$(cd /home/indexer/wazuh-indexer-plugins && git rev-parse --short HEAD)
REPORTING_HASH=$(cd /home/indexer/wazuh-indexer-reporting && git rev-parse --short HEAD)
cd /home/indexer/wazuh-indexer

PACKAGE_MIN_NAME=$(bash build-scripts/baptizer.sh -m \
    -a "$ARCHITECTURE" \
    -d "$DISTRIBUTION" \
    -r "$REVISION" \
    -l "$PLUGINS_HASH" \
    -e "$REPORTING_HASH" \
    "$(if [ "$IS_STAGE" = "true" ]; then echo "-x"; fi)")

PACKAGE_NAME=$(bash build-scripts/baptizer.sh \
    -a "$ARCHITECTURE" \
    -d "$DISTRIBUTION" \
    -r "$REVISION" \
    -l "$PLUGINS_HASH" \
    -e "$REPORTING_HASH" \
    "$(if [ "$IS_STAGE" = "true" ]; then echo "-x"; fi)")

bash build-scripts/build.sh \
    -a "$ARCHITECTURE" \
    -d "$DISTRIBUTION" \
    -n "$PACKAGE_MIN_NAME"

bash build-scripts/assemble.sh \
    -a "$ARCHITECTURE" \
    -d "$DISTRIBUTION" \
    -r "$REVISION"

mkdir -p /artifacts/dist/
ls -ll /home/indexer/wazuh-indexer/artifacts/
ls -ll /home/indexer/wazuh-indexer/artifacts/dist/
mv /home/indexer/wazuh-indexer/artifacts/dist/"$PACKAGE_NAME" /artifacts/dist/

echo "Build and packaging process completed successfully!"
