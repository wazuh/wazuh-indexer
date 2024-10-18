#!/bin/bash

## SPDX-License-Identifier: Apache-2.0
## The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

## Usage: ./publish_images.sh <quay-username> <quay-password>

QUAY_IO_USERNAME=$1
QUAY_IO_PASSWORD=$2

build_and_push() {
    ENV=$1
    IMAGE_NAME="wazuh-indexer"

    if [ "$ENV" == "prod" ]; then
        TAG="latest"
    else
        TAG="$ENV"
    fi

    # Navigate to the Dockerfile directory
    cd "$(git rev-parse --show-toplevel)/docker/$ENV"

    # Build the Docker image
    docker build -t $IMAGE_NAME:$TAG .

    # Login to Quay.io
    echo $QUAY_IO_PASSWORD | docker login quay.io -u $QUAY_IO_USERNAME --password-stdin

    # Push the Docker image to Quay.io
    docker push $IMAGE_NAME:$TAG

    # Logout from Quay.io
    docker logout quay.io

    echo "Docker image $IMAGE_NAME:$TAG successfully pushed to quay.io"
}

# Build and push for each environment
build_and_push "ci"
build_and_push "dev"
build_and_push "prod"

echo "All images successfully built and pushed."
