#!bin/bash

# This script is used to connect to the Vagrant machine or to the AWS instance.
#
# Usage: connect.sh [architecture]
#
# Arguments:
# - architecture    [required] The architecture of the target machine (x64 or arm64).

if [ -z "$1" ]; then
    echo "Error: Architecture argument is required."
    exit 1
fi

# ======
# Connect to the machine
# ======
if $1 == "x64" then
    ssh_config=$(vagrant ssh-config)

    identity_file=$(echo "$ssh_config" | grep IdentityFile | awk '{print $2}')
    port=$(echo "$ssh_config" | grep Port | awk '{print $2}')
    hostname=$(echo "$ssh_config" | grep HostName | awk '{print $2}')

    scp -i $identity_file -P $port $1 vagrant@$hostname:/home/vagrant/ 
elif $2 == "arm64" then
    # TODO: Talk with DevOps to get the correct credentials
else
    echo "Error in the architecture"
    exit 1
fi