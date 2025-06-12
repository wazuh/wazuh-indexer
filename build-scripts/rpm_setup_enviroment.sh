#!/bin/bash

# This script is used to set up the environment to perform the smoke tests in RPM distribution.
#
# Usage: rpm_setup_enviroment.sh [architecture] [run_id]
#
# Arguments:
# - architecture    [required] The architecture of the target machine (x64 or arm64).
# - run_id          [required] The run id to use it for the allocator instance name.


if [ -z "$2" ]; then
    echo "Error: Architecture argument and run_id is required."
    exit 1
fi
# =====
# Deployments based on architecture
# =====
if [ "$1" = "x64" ]; then
    python3 wazuh-automation/deployability/modules/allocation/main.py --action create --provider aws --size large --composite-name linux-centos-9-amd64 --instance-name "indexer_amd_$2" --inventory-output "/tmp/inventory.yaml" --track-output "/tmp/track.yaml" --label-team indexer --label-termination-date 1d --working-dir /tmp/indexer
elif [ "$1" = "arm64" ]; then
   python3 wazuh-automation/deployability/modules/allocation/main.py --action create --provider aws --size large --composite-name  linux-centos-8-arm64 --instance-name "indexer_arm_$2" --inventory-output "/tmp/inventory.yaml" --track-output "/tmp/track.yaml" --label-team indexer --label-termination-date 1d --working-dir /tmp/indexer
else
    echo "Error: Invalid architecture argument. Use 'x64' or 'arm64'."
    exit 1
fi
