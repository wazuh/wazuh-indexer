#!/bin/bash

# Wazuh-indexer securityadmin wrapper
# Copyright (C) 2022, Wazuh Inc.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.
#
# Loads the security configuration of this node into the cluster, once, with the admin
# certificate the package issued. It runs as root: the admin pair is root's alone, so that the
# service account cannot act as the security administrator. Nothing here runs a host tool but
# openssl and ip; everything else is a bash builtin or coreutils.

CONFIG_PATH="/etc/wazuh-indexer"

if [ ! -d "${CONFIG_PATH}" ]; then
    echo "ERROR: it was not possible to find ${CONFIG_PATH}"
    exit 1
fi

CONFIG_FILE="${CONFIG_PATH}/opensearch.yml"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: it was not possible to find ${CONFIG_FILE}"
    exit 1
fi

INSTALL_PATH="/usr/share/wazuh-indexer"

if [ ! -d "${INSTALL_PATH}" ]; then
        echo "ERROR: it was not possible to find ${INSTALL_PATH}"
        exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: this tool must run as root"
    exit 1
fi

# config_line <key> <file>: the lines of <file> that contain <key> (what `grep <key> <file>`
# printed).
config_line() {
    [ -r "$2" ] || return 1
    while IFS= read -r _cl_line || [ -n "${_cl_line}" ]; do
        case "${_cl_line}" in *"$1"*) printf '%s\n' "${_cl_line}" ;; esac
    done < "$2"
}

HOST=""
OPTIONS="-icl -nhnv"
WAZUH_INDEXER_ROOT_CA="$(config_line http.pemtrustedcas "${CONFIG_FILE}")"
WAZUH_INDEXER_ROOT_CA="${WAZUH_INDEXER_ROOT_CA##*: }"
WAZUH_INDEXER_ROOT_CA="$(echo "${WAZUH_INDEXER_ROOT_CA}" | tr -d "[\"\']")"
WAZUH_INDEXER_ADMIN_PATH="$(dirname "${WAZUH_INDEXER_ROOT_CA}" 2>&1)"
SECURITY_PATH="${INSTALL_PATH}/plugins/opensearch-security"
SECURITY_CONFIG_PATH="${CONFIG_PATH}/opensearch-security"

# -----------------------------------------------------------------------------

trap ctrl_c INT

# The processes whose parent is $1, read from /proc/<pid>/stat (the fourth field, after the
# command name in parentheses): what pkill -P reads.
children_of() {
    _co_parent=$1
    for _co_stat in /proc/[0-9]*/stat; do
        IFS= read -r _co_line < "${_co_stat}" 2>/dev/null || continue
        _co_pid=${_co_stat#/proc/}; _co_pid=${_co_pid%/stat}
        set -- ${_co_line##*) }
        [ "$2" = "${_co_parent}" ] && printf '%s\n' "${_co_pid}"
    done
}

clean(){

    exit_code=$1
    # Stop what this script started: securityadmin.sh and its JVM.
    for _child in $(children_of $$); do
        kill "${_child}" > /dev/null 2>&1 || true
    done
    exit "${exit_code}"

}

ctrl_c() {
    clean 1
}

# -----------------------------------------------------------------------------

getNetworkHost() {

    HOST=$(config_line "network.host:" "${CONFIG_FILE}")
    NH="network.host: "
    HOST="${HOST//$NH}"
    HOST=$(echo "${HOST}" | tr -d "[\"\']")

    isIP=""; isDNS=""
    [[ "${HOST}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && isIP=${HOST}
    [[ "${HOST}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](\.[a-zA-Z-]{2,})+$ ]] && isDNS=${HOST}

    # Allow to find ip with an interface
    if [ -z "${isIP}" ] && [ -z "${isDNS}" ]; then
        interface="${HOST//_}"
        read -r _ _ _ HOST _ <<< "$(ip -o -4 addr list "${interface}" 2>/dev/null)"
        HOST="${HOST%%/*}"
    fi

    if [ "${HOST}" = "0.0.0.0" ]; then
        HOST="127.0.0.1"
    fi

    if [ -z "${HOST}" ]; then
        echo "ERROR: network host not valid, check ${CONFIG_FILE}"
        exit 1
    fi

}

# -----------------------------------------------------------------------------
getPort() {

    PORT=$(config_line 'http.port' "${CONFIG_FILE}")
    if [ "${PORT}" ]; then
        PORT="${PORT#* }"
        PORT="${PORT%% *}"
        PORT="${PORT%%-*}"
    else
        PORT="9200"
    fi
    PORT=$(echo "${PORT}" | tr -d "[\"\']")

}
# -----------------------------------------------------------------------------

# securityadmin authenticates with a certificate, and the cluster accepts it only if its subject
# is listed in plugins.security.authcz.admin_dn. Replacing the certificates without updating that
# setting fails with "is not an admin user", which does not say what is wrong.
checkAdminDn() {

    admin_cert="${WAZUH_INDEXER_ADMIN_PATH}/admin.pem"
    [ -f "${admin_cert}" ] || return 0

    dn=$(openssl x509 -in "${admin_cert}" -noout -subject -nameopt RFC2253 2>/dev/null)
    dn="${dn#subject=}"
    dn="${dn#"${dn%%[! ]*}"}"
    [ -n "${dn}" ] || return 0

    if [ -z "$(config_line "${dn}" "${CONFIG_FILE}")" ]; then
        echo "WARNING: the subject of ${admin_cert}"
        echo "           ${dn}"
        echo "         is not listed in plugins.security.authcz.admin_dn of ${CONFIG_FILE}."
        echo "         The cluster will refuse it with \"is not an admin user\". Add it there and retry."
    fi

}

securityadmin() {

    checkAdminDn

    if [ ! -d "${SECURITY_PATH}" ]; then
        echo "ERROR: it was not possible to find ${SECURITY_PATH}"
        exit 1
    elif [ ! -d "${INSTALL_PATH}/jdk" ]; then
        echo "ERROR: it was not possible to find ${INSTALL_PATH}/jdk"
        exit 1
    fi

    if [ -f "${WAZUH_INDEXER_ADMIN_PATH}/admin.pem" ] && [ -f "${WAZUH_INDEXER_ADMIN_PATH}/admin-key.pem" ] && [ -f "${WAZUH_INDEXER_ROOT_CA}" ]; then
        # As root, from /: the JVM's performance data goes to /tmp/hsperfdata_root, and nothing
        # the service account could plant is executed or read with its privileges.
        (cd / && OPENSEARCH_CONF_DIR="${CONFIG_PATH}" JAVA_HOME="${INSTALL_PATH}/jdk" "${SECURITY_PATH}/tools/securityadmin.sh" -cd "${SECURITY_CONFIG_PATH}" -cacert "${WAZUH_INDEXER_ROOT_CA}" -cert "${WAZUH_INDEXER_ADMIN_PATH}/admin.pem" -key "${WAZUH_INDEXER_ADMIN_PATH}/admin-key.pem" -h "${HOST}" -p "${PORT}" ${OPTIONS})
    else
        echo "ERROR: this tool try to find admin.pem and admin-key.pem in ${WAZUH_INDEXER_ADMIN_PATH} but it couldn't. In this case, you must run manually the Indexer security initializer by running the command: JAVA_HOME=\"/usr/share/wazuh-indexer/jdk\" OPENSEARCH_CONF_DIR=\"/etc/wazuh-indexer\" /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -cd /etc/wazuh-indexer/opensearch-security -cacert /path/to/root-ca.pem -cert /path/to/admin.pem -key /path/to/admin-key.pem -h ${HOST} -p ${PORT} ${OPTIONS} replacing /path/to/ by your certificates path."
        exit 1
    fi

}

help() {
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "    -ho, --host <host>    [Optional] Target IP or DNS to configure security."
    echo "    --port <port>         [Optional] wazuh-indexer security port."
    echo "    --options <options>   [Optional] Custom securityadmin options."
    echo "    -h, --help            Show this help."
    echo
    exit "$1"
}


main() {

    getNetworkHost
    getPort

    while [ -n "$1" ]
    do
        case "$1" in
        "-h"|"--help")
            help 0
            ;;
        "-ho"|"--host")
            if [ -n "$2" ]; then
                HOST="$2"
                HOST=$(echo "${HOST}" | tr -d "[\"\']")
                isIP=""; isDNS=""
                [[ "${2}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && isIP=${2}
                [[ "${2}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](\.[a-zA-Z]{2,})+$ ]] && isDNS=${2}
                if [[ -z "${isIP}" ]] &&  [[ -z "${isDNS}" ]]; then
                    echo "The given information does not match with an IP address or a DNS."
                    exit 1
                fi
                shift 2
            else
                help 1
            fi
            ;;
        "--port")
            if [ -n "$2" ]; then
                PORT="$2"
                PORT=$(echo "${PORT}" | tr -d "[\"\']")
                if ! [[ "${2}" =~ ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
                    echo "The given information does not match with a valid PORT number."
                    exit 1
                fi
                shift 2
            else
                help 1
            fi
            ;;
        "--options")
            if [ -n "$2" ]; then
                OPTIONS="$2"
                shift 2
            else
                help 1
            fi
            ;;
        *)
            help 1
        esac
    done

    securityadmin

}

main "$@"
