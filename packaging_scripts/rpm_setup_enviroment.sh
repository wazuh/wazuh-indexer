#!/bin/bash

# This script is used to set up the environment to perform the smoke tests in RPM distribution.
#
# Usage: rpm_setup_enviroment.sh [architecture]
#
# Arguments:
# - architecture    [required] The architecture of the target machine (x64 or arm64).


if [ -z "$1" ]; then
    echo "Error: Architecture argument is required."
    exit 1
fi
# ======
# Install dependencies
# ======
yum update

yum install python3
yum install python3-pip
yum install python3-pip

# ======
# Configure the enviroment
# ======

git clone https://github.com/wazuh/wazuh-automation.git
cd wazuh-automation
git checkout $(./product_version.sh)

pip3 install -r deployability/deps/requirements.txt

# =====
# Deployments based on architecture
# =====
if $1 == "x64" then
    python3 modules/allocation/main.py --action create --provider vagrant --size medium --composite-name linux-redhat-9-amd64 --instance-name "redhat_9_amd_medium_vagrant" --inventory-output "/tmp/dtt1-poc/agent-linux-redhat-9-amd64/inventory.yaml" --track-output "/tmp/dtt1-poc/agent-linux-redhat-9-amd64/track.yaml"
elif $1 == "arm64" then
    python3 modules/allocation/main.py --action create --provider aws --size medium --composite-name linux-redhat-9-arm64 --inventory-output "/tmp/dtt1-poc/agent-linux-redhat-9-arm64/inventory.yaml" --track-output "/tmp/dtt1-poc/agent-linux-redhat-9-arm64/track.yaml" --label-termination-date "1d"  --label-team indexer --instance-name "redhat_9_amd_medium_aws"
else
 echo "Error in the architecture"
 exit 1
fi