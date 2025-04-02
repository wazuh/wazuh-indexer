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
# Configure the enviroment
# ======
cd wazuh-automation
sudo pip3 install -r deployability/deps/requirements.txt
cd deployability
# =====
# Deployments based on architecture
# =====
if [ "$1" = "x64" ]; then
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install vagrant

    sudo apt install virtualbox
    sudo python3 modules/allocation/main.py --action create --provider vagrant --size medium --composite-name linux-redhat-9-amd64 --instance-name "redhat_9_amd_medium_vagrant" --inventory-output "/inventory.yaml" --track-output "/track.yaml"
elif [ "$1" != "arm64" ]; then
    echo "Error: Invalid architecture argument. Use 'x64' or 'arm64'."
    exit 1
fi