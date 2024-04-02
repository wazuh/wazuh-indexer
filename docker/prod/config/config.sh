#!/bin/bash

# Wazuh Docker Copyright (C) 2017, Wazuh Inc. (License GPLv2)
# This has to be exported to make some magic below work.
export DH_OPTIONS

export NAME=wazuh-indexer
export TARGET_DIR=${CURDIR}/debian/${NAME}

# Package build options
export LOG_DIR=/var/log/${NAME}
export LIB_DIR=/var/lib/${NAME}
export PID_DIR=/run/${NAME}
export INSTALLATION_DIR=/usr/share/${NAME}
export CONFIG_DIR=${INSTALLATION_DIR}/config
export BASE_DIR=${NAME}-*

rm -rf ${INSTALLATION_DIR:?}/
tar -xf "${WAZUH_INDEXER_TAR_NAME}"

## TOOLS

## Variables
TOOLS_PATH=${NAME}-${WAZUH_VERSION}/plugins/opensearch-security/tools
CERT_TOOL=${TOOLS_PATH}/wazuh-certs-tool.sh

# generate certificates
cp $CERT_TOOL .
chmod 755 wazuh-certs-tool.sh && bash wazuh-certs-tool.sh -A

# copy to target
mkdir -p ${TARGET_DIR}${INSTALLATION_DIR}
mkdir -p ${TARGET_DIR}${INSTALLATION_DIR}/opensearch-security/
mkdir -p ${TARGET_DIR}${CONFIG_DIR}
mkdir -p ${TARGET_DIR}${LIB_DIR}
mkdir -p ${TARGET_DIR}${LOG_DIR}
mkdir -p ${TARGET_DIR}/etc/init.d
mkdir -p ${TARGET_DIR}/etc/default
mkdir -p ${TARGET_DIR}/usr/lib/tmpfiles.d
mkdir -p ${TARGET_DIR}/usr/lib/sysctl.d
mkdir -p ${TARGET_DIR}/usr/lib/systemd/system
mkdir -p ${TARGET_DIR}${CONFIG_DIR}/certs
# Copy installation files to final location
cp -pr ${BASE_DIR}/* ${TARGET_DIR}${INSTALLATION_DIR}
cp -pr /opensearch.yml ${TARGET_DIR}${CONFIG_DIR}
# Copy Wazuh indexer's certificates
cp -pr /wazuh-certificates/demo.indexer.pem ${TARGET_DIR}${CONFIG_DIR}/certs/indexer.pem
cp -pr /wazuh-certificates/demo.indexer-key.pem ${TARGET_DIR}${CONFIG_DIR}/certs/indexer-key.pem
cp -pr /wazuh-certificates/root-ca.key ${TARGET_DIR}${CONFIG_DIR}/certs/root-ca.key
cp -pr /wazuh-certificates/root-ca.pem ${TARGET_DIR}${CONFIG_DIR}/certs/root-ca.pem
cp -pr /wazuh-certificates/admin.pem ${TARGET_DIR}${CONFIG_DIR}/certs/admin.pem
cp -pr /wazuh-certificates/admin-key.pem ${TARGET_DIR}${CONFIG_DIR}/certs/admin-key.pem

# Delete xms and xmx parameters in jvm.options
sed '/-Xms/d' -i ${TARGET_DIR}${CONFIG_DIR}/jvm.options
sed '/-Xmx/d' -i ${TARGET_DIR}${CONFIG_DIR}/jvm.options
sed -i 's/-Djava.security.policy=file:\/\/\/etc\/wazuh-indexer\/opensearch-performance-analyzer\/opensearch_security.policy/-Djava.security.policy=file:\/\/\/usr\/share\/wazuh-indexer\/opensearch-performance-analyzer\/opensearch_security.policy/g' ${TARGET_DIR}${CONFIG_DIR}/jvm.options

chmod -R 500 ${TARGET_DIR}${CONFIG_DIR}/certs
chmod -R 400 ${TARGET_DIR}${CONFIG_DIR}/certs/*

find ${TARGET_DIR} -type d -exec chmod 750 {} \;
find ${TARGET_DIR} -type f -perm 644 -exec chmod 640 {} \;
find ${TARGET_DIR} -type f -perm 664 -exec chmod 660 {} \;
find ${TARGET_DIR} -type f -perm 755 -exec chmod 750 {} \;
find ${TARGET_DIR} -type f -perm 744 -exec chmod 740 {} \;
