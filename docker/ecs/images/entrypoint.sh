#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

ECS_VERSION="${ECS_VERSION:-v8.11.0}"
INDEXER_SRC="${INDEXER_SRC:-/wazuh-indexer}"

if [ -z "$ECS_DEFINITION" ]; then
    echo "Error: ECS_DEFINITION environment variable missing."
    exit 1
fi

bash ./generate.sh "$ECS_VERSION" "$INDEXER_SRC" "$ECS_DEFINITION"
