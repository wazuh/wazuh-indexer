#!/bin/bash

# This script provisions one node of the Wazuh CCS environment.
# Usage: ./node-start.sh <node_name>
# node_name can be "ccs", "cluster_a" or "cluster_b".
#
# Every node runs a single-node Wazuh indexer cluster. cluster_a and cluster_b add a Wazuh server;
# ccs adds the Wazuh dashboard and connects to the other two as remote clusters.
#
# It runs as root and expects:
#   - ARTIFACT_URLS in the environment: the artifact list to download the packages from.
#   - root-ca.pem, root-ca.key and credentials.env in /tmp/ccs, uploaded by the Vagrantfile.
#
# The packages resolve passwords and certificates on their own when installed: certificates are
# issued from the CA staged in /etc/wazuh/ca, and any password missing from
# /etc/wazuh/credentials.env is generated and written there.

set -euo pipefail

NODE="${1-}"

# Must match the Vagrantfile.
CCS_HOSTNAME="ccs"
CLUSTER_A_IP="192.168.56.11"
CLUSTER_B_IP="192.168.56.12"

case "${NODE}" in
    ccs)       PREFIX="ccs"; IP="192.168.56.10" ;;
    cluster_a) PREFIX="ca";  IP="${CLUSTER_A_IP}" ;;
    cluster_b) PREFIX="cb";  IP="${CLUSTER_B_IP}" ;;
    *)
        echo "Usage: $0 <node_name>"
        echo "node_name can be 'ccs', 'cluster_a' or 'cluster_b'."
        exit 1
        ;;
esac

if [ -z "${ARTIFACT_URLS-}" ]; then
    echo "ARTIFACT_URLS is not set" >&2
    exit 1
fi

UPLOADS="/tmp/ccs"
DOWNLOADS="/var/tmp/ccs"
CREDENTIALS="/etc/wazuh/credentials.env"
INDEXER_CERTS="/etc/wazuh-indexer/certs"

case "$(uname -m)" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# The packages accept the CA and the credentials file only when every directory down to them is
# root-owned and closed to group and others. Whatever a previous run left is kept: the credentials
# file holds the passwords generated on this node.
stage_credentials() {
    install -d -m 0700 -o root -g root /etc/wazuh /etc/wazuh/ca
    if [ ! -f /etc/wazuh/ca/root-ca.pem ]; then
        install -m 0644 -o root -g root "${UPLOADS}/root-ca.pem" /etc/wazuh/ca/root-ca.pem
        install -m 0400 -o root -g root "${UPLOADS}/root-ca.key" /etc/wazuh/ca/root-ca.key
    fi
    if [ ! -f "${CREDENTIALS}" ]; then
        install -m 0600 -o root -g root "${UPLOADS}/credentials.env" "${CREDENTIALS}"
    fi
}

# Prints the value of a key in the credentials file. The file is parsed, never sourced.
credential() {
    awk -v key="$1" 'index($0, key "=") == 1 { value = substr($0, length(key) + 2) } END { print value }' \
        "${CREDENTIALS}" | sed -e "s/^'\(.*\)'$/\1/" -e 's/^"\(.*\)"$/\1/'
}

installed() {
    rpm -q "$1" > /dev/null
}

# Downloads a package from the artifact list. Usage: download <component>
download() {
    local key="wazuh_$1_${ARCH}_rpm"
    local url
    url=$(awk -v key="${key}:" '$1 == key { gsub(/"/, "", $2); print $2 }' "${DOWNLOADS}/artifact_urls.yaml")
    if [ -z "${url}" ]; then
        echo "${key} is not in ${ARTIFACT_URLS}" >&2
        exit 1
    fi
    echo "Downloading ${url}"
    curl -fsSL --retry 5 -o "${DOWNLOADS}/wazuh-$1.rpm" "${url}"
}

install_indexer() {
    download indexer
    # The indexer puts in its certificate the addresses of the default-route interface only, which
    # here is the provider's management interface. The clusters reach each other on the private
    # network with hostname verification enabled, so the private address has to be there too.
    WAZUH_INDEXER_CERT_SANS="DNS:$(hostname -s),IP:${IP}" dnf install -y "${DOWNLOADS}/wazuh-indexer.rpm"

    local config="/etc/wazuh-indexer/opensearch.yml"
    sed -i "s/node-1/${PREFIX}-wazuh-indexer-1/g" "${config}"
    sed -i "s/^cluster\.name:.*$/cluster.name: \"${PREFIX}-cluster\"/" "${config}"
    # Listen on every interface, since the server and the dashboard connect through localhost, but
    # publish the private address, which is the one the CCS node connects to.
    echo "network.publish_host: \"${IP}\"" >> "${config}"

    if [ "${NODE}" != "ccs" ]; then
        # A remote cluster only accepts the CCS node if its certificate is listed as a node's. Both
        # are issued by the package with the same DN but for the CN, which is the host name.
        local node_dn ccs_dn
        node_dn=$(openssl x509 -in "${INDEXER_CERTS}/indexer.pem" -noout -subject -nameopt RFC2253 | sed 's/^subject= *//')
        ccs_dn=$(echo "${node_dn}" | sed "s/\(^\|,\)CN=[^,]*/\1CN=${CCS_HOSTNAME}/")
        sed -i "/^plugins\.security\.nodes_dn:/a - \"${ccs_dn}\"" "${config}"
    fi

    systemctl daemon-reload
    systemctl enable --now wazuh-indexer

    # Load the security configuration, with the passwords the package wrote in it, into the cluster.
    /usr/share/wazuh-indexer/bin/indexer-security-init.sh
}

install_manager() {
    download manager
    dnf install -y "${DOWNLOADS}/wazuh-manager.rpm"

    systemctl daemon-reload
    systemctl enable --now wazuh-manager
}

dashboard_keystore() {
    (cd / && runuser -u wazuh-dashboard -- env OSD_PATH_CONF=/etc/wazuh-dashboard \
        /usr/share/wazuh-dashboard/bin/opensearch-dashboards-keystore "$@")
}

install_dashboard() {
    download dashboard
    dnf install -y "${DOWNLOADS}/wazuh-dashboard.rpm"

    local config="/etc/wazuh-dashboard/opensearch_dashboards.yml"
    # The account the dashboard authenticates to the servers with: the one the package's own
    # default host uses, so that it matches the server build (wazuh-wui before its rename to
    # wazuh-internal-client).
    local api_user
    api_user=$(awk '/^wazuh_core\.hosts:/ { hosts = 1 } hosts && $1 == "username:" { print $2; exit }' "${config}")
    api_user="${api_user:-wazuh-internal-client}"

    # Replace the default host, a server on this node, with the servers of both remote clusters.
    local hosts
    hosts=$(awk '/^wazuh_core\.hosts:/ { skip = 1; next } skip && /^[[:space:]]/ { next } { skip = 0; print }' "${config}")
    cat > "${config}" << EOF
${hosts}
wazuh_core.hosts:
  cluster-a:
    url: https://${CLUSTER_A_IP}
    port: 55000
    username: ${api_user}
    run_as: true
  cluster-b:
    url: https://${CLUSTER_B_IP}
    port: 55000
    username: ${api_user}
    run_as: true
EOF

    # Both servers were installed with the WAZUH_MANAGER_WUI_PASSWORD from the same credentials file.
    local password
    password=$(credential WAZUH_MANAGER_WUI_PASSWORD)
    dashboard_keystore remove wazuh_core.hosts.default.password > /dev/null 2>&1 || true
    for host in cluster-a cluster-b; do
        printf '%s' "${password}" | dashboard_keystore add --force --stdin "wazuh_core.hosts.${host}.password" > /dev/null
    done

    systemctl daemon-reload
    systemctl enable --now wazuh-dashboard
}

# Authenticates with the admin certificate, so no password is needed.
configure_remote_clusters() {
    curl -fsS --cacert "${INDEXER_CERTS}/root-ca.pem" \
        --cert "${INDEXER_CERTS}/admin.pem" --key "${INDEXER_CERTS}/admin-key.pem" \
        -X PUT "https://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d @- << EOF
{
    "persistent": {
        "cluster.remote": {
            "ca-wazuh-indexer-1": { "seeds": ["${CLUSTER_A_IP}:9300"] },
            "cb-wazuh-indexer-1": { "seeds": ["${CLUSTER_B_IP}:9300"] }
        }
    }
}
EOF
    echo
}

systemctl disable --now firewalld > /dev/null 2>&1 || true

mkdir -p "${DOWNLOADS}"
curl -fsSL --retry 5 -o "${DOWNLOADS}/artifact_urls.yaml" "${ARTIFACT_URLS}"
stage_credentials

# A component already installed by a previous run is left as it is. Not written as
# `installed ... || install_...`: errexit is ignored inside a function called that way.
if ! installed wazuh-indexer; then
    install_indexer
fi
if [ "${NODE}" == "ccs" ]; then
    if ! installed wazuh-dashboard; then
        install_dashboard
    fi
    configure_remote_clusters
else
    if ! installed wazuh-manager; then
        install_manager
    fi
fi

rm -rf "${UPLOADS}" "${DOWNLOADS}"

echo "${NODE} is ready. The passwords of this node are in ${CREDENTIALS}."
