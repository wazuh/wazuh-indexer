#!/bin/bash

# This scripts configures the enviroment for the diferent nodes in the ccs.
# Usage: ./node-start.sh <node_name> <version>
# node_name can be "ccs", "cluster_a" or "cluster_b".
#
# It is used to create the certificates and configure the nodes for the cluster.

if [ -z "$2" ]; then
    echo "Usage: $0 <node_name> <version>"
    echo "node_name can be 'ccs', 'cluster_a' or 'cluster_b'."
    echo "version is the Wazuh version to use, e.g., 4.12.0"
    exit 1
fi

NODE=$1
WAZUH_VERSION=$2

# Check if the node name is valid
if [[ "$NODE" != "ccs" && "$NODE" != "cluster_a" && "$NODE" != "cluster_b" ]]; then
    echo "Invalid node name: $NODE"
    echo "Valid node names are: ccs, cluster_a, cluster_b"
    exit 1
fi


if [ "$NODE" == "ccs" ]; then
    # Change to the root user
    sudo su

    # Create the certificates for the Wazuh ccs node
    tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .
    rm -rf ./wazuh-certificates

    # Install wazuh-indexer
    yum install -y coreutils
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    echo -e '[wazuh]\ngpgcheck=1\ngpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH\nenabled=1\nname=EL-$releasever - Wazuh\nbaseurl=https://packages.wazuh.com/4.x/yum/\nprotect=1' | tee /etc/yum.repos.d/wazuh.repo
    yum update -y

    yum -y install wazuh-indexer-$WAZUH_VERSION-1

    # Configure the wazuh-indexer /etc/wazuh-indexer/opensearch.yml file
    sed -i 's/node-1/ccs-wazuh-indexer-1/g' /etc/wazuh-indexer/opensearch.yml
    sed -i 's/^network\.host:.*$/network.host: "192.168.56.10"/' /etc/wazuh-indexer/opensearch.yml
    sed -i 's/^cluster\.name:.*$/cluster.name: "ccs-cluster"/' /etc/wazuh-indexer/opensearch.yml



    # Deploy the certificates
    NODE_NAME=ccs-wazuh-indexer-1
    mkdir /etc/wazuh-indexer/certs
    tar -xf ./wazuh-certificates.tar -C /etc/wazuh-indexer/certs/ ./$NODE_NAME.pem ./$NODE_NAME-key.pem ./admin.pem ./admin-key.pem ./root-ca.pem
    mv -n /etc/wazuh-indexer/certs/$NODE_NAME.pem /etc/wazuh-indexer/certs/indexer.pem
    mv -n /etc/wazuh-indexer/certs/$NODE_NAME-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
    chmod 500 /etc/wazuh-indexer/certs
    chmod 400 /etc/wazuh-indexer/certs/*
    chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs

    # Start the Wazuh indexer service
    systemctl daemon-reload
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer

    # Initialize the Wazuh indexer cluster
    /usr/share/wazuh-indexer/bin/indexer-security-init.sh

    # Install wazuh-dashboard
    yum install libcap
    yum -y install wazuh-dashboard-$WAZUH_VERSION-1

    # Configure the wazuh-dashboard /etc/wazuh-dashboard/opensearch_dashboards.yml file
    sed -i 's|^opensearch\.hosts:.*$|opensearch.hosts: "https://192.168.56.10:9200"|' /etc/wazuh-dashboard/opensearch_dashboards.yml

    # Deploy the certificates
    NODE_NAME=ccs-wazuh-dashboard
    mkdir /etc/wazuh-dashboard/certs
    tar -xf ./wazuh-certificates.tar -C /etc/wazuh-dashboard/certs/ ./$NODE_NAME.pem ./$NODE_NAME-key.pem ./root-ca.pem
    mv -n /etc/wazuh-dashboard/certs/$NODE_NAME.pem /etc/wazuh-dashboard/certs/dashboard.pem
    mv -n /etc/wazuh-dashboard/certs/$NODE_NAME-key.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
    chmod 500 /etc/wazuh-dashboard/certs
    chmod 400 /etc/wazuh-dashboard/certs/*
    chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs

    # Start the Wazuh dashboard service
    systemctl daemon-reload
    systemctl enable wazuh-dashboard
    systemctl start wazuh-dashboard

    # Configure the Wazuh dashboard /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml file
    cat <<EOF > /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
---
hosts:
  - Cluster A:
      url: https://192.168.56.11
      port: 55000
      username: wazuh-wui
      password: wazuh-wui
      run_as: true
  - Cluster B:
      url: https://192.168.56.12
      port: 55000
      username: wazuh-wui
      password: wazuh-wui
      run_as: true
EOF

    # Restart the Wazuh dashboard service to apply the changes
    systemctl restart wazuh-dashboard

    
fi
