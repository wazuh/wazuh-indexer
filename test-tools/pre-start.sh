#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Download the Wazuh certs tool
curl -sO https://packages.wazuh.com/4.9/wazuh-certs-tool.sh

# Make the script executable
chmod +x ./wazuh-certs-tool.sh

# Run the Wazuh certs tool
OPENSSL_CONF="/etc/ssl/openssl.cnf" ./wazuh-certs-tool.sh -A

# Create a tarball of the generated certificates
tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .

# Clean up
rm -rf ./wazuh-certificates wazuh-certs-tool.sh *.log

echo "Setup complete and certificates archived."
