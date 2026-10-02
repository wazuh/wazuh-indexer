#!/bin/sh

# Copyright (C) 2026, Wazuh Inc.
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.
#
# The indexer's half of the credential resolution ladder.
#
# The shared half -- the credentials file, its locking, password generation and validation, and the
# CA -- lives in lib/wazuh-credentials.sh, which the manager, the indexer and the dashboard must
# agree on exactly. It is owned by wazuh-installation-assistant and downloaded by
# build-scripts/assemble.sh; it is NOT in this repository.
#
# The indexer owns all three of its accounts and consumes none, so a password is never unresolved:
# generating it is what makes it true. Only a certificate can be, and only when the host was handed
# a trust anchor with no signing key and no issued pair.
#
# Resolution happens once. A run that resolves everything it was responsible for records the fact
# in a marker file, and every later run exits immediately -- which is what lets an operator rotate
# a password or stage their own certificates and keep them across restarts and upgrades. --clear is
# the way back. Modes:
#
#   --install    From a fresh postinst / %post. Never fails: a maintainer script that aborts leaves
#                the package half-configured. It is the only mode that replaces DN settings that
#                already have a value.
#   --upgrade    From postinst / %post over a previous version.
#   --prestart   From the unit's ExecStartPre and the SysV start. Exits non-zero naming whatever it
#                could not resolve, so the service does not start on a half-resolved node.
#   --clear      Takes back everything this component resolved, for images built by installing the
#                package. Nothing in the product calls it.
#
# Every mode resolves passwords, certificates and the JDK truststore entry while the marker is
# absent; the marker, not the mode, is what stops it happening twice. Nothing here opens a network
# connection: presence and format only.
#
# The design behind all of this is documented in the development guide, "Credential and TLS
# resolution".

MODE="prestart"
DIR=""

# ${1-} rather than $1, matching the helpers' convention: the bare form is an "unbound variable"
# error under a caller that runs us with `set -u`, and `shift 2` on a lone -H is a hard error in
# dash rather than a diagnosable one.
while [ -n "${1-}" ]; do
    case "${1-}" in
        --install)  MODE="install" ; shift ;;
        --upgrade)  MODE="upgrade" ; shift ;;
        --prestart) MODE="prestart"; shift ;;
        --clear)    MODE="clear"   ; shift ;;
        -H)
            if [ -z "${2-}" ]; then
                echo "resolve-credentials: -H needs a directory" >&2
                exit 2
            fi
            DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--install|--upgrade|--prestart|--clear] [-H <home>]"
            exit 0
            ;;
        *)
            echo "resolve-credentials: unknown option: ${1-}" >&2
            exit 2
            ;;
    esac
done

# Derive the installation directory from our own location, so a tree installed somewhere other
# than the default resolves against itself rather than against a compiled-in path.
if [ -z "${DIR}" ]; then
    _self=$(readlink -f "$0" 2>/dev/null || echo "$0")
    DIR=$(dirname "$(dirname "${_self}")")
fi

_self_dir=$(dirname "$0")

# WAZUH_SHARED_HELPER_DIR overrides where to look, which is what lets the test suites drive the
# ladder without an install. On an installed node the first branch wins and the rest never runs.
if [ -n "${WAZUH_SHARED_HELPER_DIR-}" ] && [ -f "${WAZUH_SHARED_HELPER_DIR}/wazuh-credentials.sh" ]; then
    SHARED_HELPER_DIR="${WAZUH_SHARED_HELPER_DIR}"
elif [ -f "${DIR}/lib/wazuh-credentials.sh" ]; then
    SHARED_HELPER_DIR="${DIR}/lib"
elif [ -f "${_self_dir}/wazuh-credentials.sh" ]; then
    SHARED_HELPER_DIR="${_self_dir}"
else
    echo "resolve-credentials: cannot find wazuh-credentials.sh" >&2
    echo "        it is downloaded from wazuh-installation-assistant by build-scripts/assemble.sh" >&2
    exit 2
fi

. "${SHARED_HELPER_DIR}/wazuh-credentials.sh"

CONFIG_DIR="${WAZUH_INDEXER_CONFIG_DIR-/etc/wazuh-indexer}"
INTERNAL_USERS="${CONFIG_DIR}/opensearch-security/internal_users.yml"
SECURITY_TOOLS="${DIR}/plugins/opensearch-security/tools"
CONFIG_FILE="${CONFIG_DIR}/opensearch.yml"
CERTS_DIR="${CONFIG_DIR}/certs"
DATA_DIR="${WAZUH_INDEXER_DATA_DIR-/var/lib/wazuh-indexer}"
PID_DIR="${WAZUH_INDEXER_PID_DIR-/run/wazuh-indexer}"

# Records that this installation resolved its credentials and its TLS material. Once it exists
# nothing is resolved again, which is what protects an operator who rotated a password or staged
# their own certificates. It holds no secret, and internal_users.yml cannot take its place: that
# file ships with the package.
MARKER="${DATA_DIR}/.initialized"

OWNED_KEYS="WAZUH_INDEXER_ADMIN_PASSWORD WAZUH_INDEXER_KIBANASERVER_PASSWORD WAZUH_INDEXER_MANAGER_PASSWORD"

LOG_TAG="resolve-credentials"

log() {
    echo "${LOG_TAG}: $*"
}

err() {
    echo "${LOG_TAG}: $*" >&2
}

# Accumulated verdicts. A key is *unresolved* when nothing supplied it and we may not invent it;
# it is *invalid* when something supplied it and the value failed the policy. The two are reported
# differently because they need different fixes, but both block the start.
UNRESOLVED=""
INVALID=""

mark_unresolved() {
    UNRESOLVED="${UNRESOLVED} $1"
}

mark_invalid() {
    INVALID="${INVALID} $1"
}

# Process environment first, then the credentials file: an orchestrator setting a value should not
# be overridden by a file left behind from an earlier install. An empty value counts as absent.
# Prints the value and returns 0 when set, 1 when absent, 2 when the file itself is unusable.

# The wazuh-docker names that predate the scoped ones, accepted from the environment only:
# an unscoped DASHBOARD_PASSWORD is meaningless in a file three components share.
alias_for() {
    case "$1" in
        WAZUH_INDEXER_KIBANASERVER_PASSWORD) printf '%s' "DASHBOARD_PASSWORD" ;;
        *) return 1 ;;
    esac
}

setting_get() {
    _sg_name="$1"

    if eval "[ \"\${${_sg_name}+x}\" = x ]"; then
        eval "_sg_env=\${${_sg_name}-}"
        if [ -n "${_sg_env}" ]; then
            printf '%s' "${_sg_env}"
            return 0
        fi
        return 1
    fi

    # The alias is an environment channel, so it still outranks the file.
    if _sg_alias=$(alias_for "${_sg_name}"); then
        if eval "[ \"\${${_sg_alias}+x}\" = x ]"; then
            eval "_sg_env=\${${_sg_alias}-}"
            if [ -n "${_sg_env}" ]; then
                printf '%s' "${_sg_env}"
                return 0
            fi
        fi
    fi

    _sg_status=0
    _sg_value=$(wazuh_env_get "${_sg_name}") || _sg_status=$?
    case "${_sg_status}" in
        0) [ -n "${_sg_value}" ] || return 1
           printf '%s' "${_sg_value}"
           return 0
           ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

# A supplied password may only use the generator's alphabet, matching the manager so that one value
# is accepted by both realms. The set is matched by `LC_ALL=C tr` rather than by a glob in the
# shell: ranges are locale-dependent and maintainer scripts inherit whatever locale the operator's
# session happens to carry. `printf` is a builtin, so the value reaches `tr` over a pipe and never
# through a command line.
password_is_valid() {
    _piv_rest=$(printf '%s' "$1" | LC_ALL=C tr -d 'A-Za-z0-9.,_+:@%^=~-') || return 1
    [ -z "${_piv_rest}" ] || return 1
    wazuh_password_validate "$1"
}

resolution_is_complete() {
    [ -f "${MARKER}" ]
}

# Written only when everything this mode was responsible for came out resolved. A partial run must
# not record completion: an install that could not issue certificates has to be able to finish the
# job on the next one, and a marker written over a half-resolved node would make that impossible
# without manual intervention.
mark_complete() {
    [ -d "${DATA_DIR}" ] || mkdir -p "${DATA_DIR}" 2>/dev/null || return 0
    : > "${MARKER}" 2>/dev/null || {
        err "could not record completion in ${MARKER}; the next start would resolve again"
        return 1
    }
    chmod 600 "${MARKER}" 2>/dev/null || true
    log "resolution complete; recorded in ${MARKER}"
}

# -----------------------------------------------------------------------------------------
# Owned: the three internal users
#
# admin, kibanaserver and wazuh-manager ship with a ${NAME} placeholder for a hash. Each value is
# resolved, published to the credentials file for the manager and the dashboard, and written here
# as a bcrypt digest. Loading it into the cluster is the operator's separate, manual step.
# -----------------------------------------------------------------------------------------

# Which account in internal_users.yml each key is the password for. The mapping is fixed at build
# time: add_configuration_files() in build-scripts/assemble.sh writes these same placeholders into
# the file the package ships.
account_for() {
    case "$1" in
        WAZUH_INDEXER_ADMIN_PASSWORD)        printf '%s' "admin" ;;
        WAZUH_INDEXER_KIBANASERVER_PASSWORD) printf '%s' "kibanaserver" ;;
        WAZUH_INDEXER_MANAGER_PASSWORD)      printf '%s' "wazuh-manager" ;;
        *) return 1 ;;
    esac
}

# True while the account is still waiting for its digest -- or is not in this build's file at all,
# which is nothing to wait for and nothing to contradict.
placeholder_is_pending() {
    _pip_account=$(account_for "$1") || return 0
    grep -q "^${_pip_account}:" "${INTERNAL_USERS}" 2>/dev/null || return 0
    grep -qF "\${${1}}" "${INTERNAL_USERS}" 2>/dev/null
}

# Bcrypt one password with the security plugin's own tool, so the digest matches what the plugin
# expects without this script knowing anything about cost factors or formats.
#
# The value reaches hash.sh through hash.sh's own environment, never on a command line: -p would
# put it in argv, which is world-readable in ps. OPENSEARCH_JAVA_HOME is pinned to the bundled JDK
# because hash.sh otherwise falls back to whatever `which java` finds, which in a maintainer script
# may be nothing. The output is matched against the bcrypt shape rather than taken whole, so the
# warning hash.sh prints on that fallback can never end up in the configuration.
hash_password() {
    _hp_digest=$(
        WAZUH_INDEXER_SECRET="$1" OPENSEARCH_JAVA_HOME="${DIR}/jdk" \
            "${SECURITY_TOOLS}/hash.sh" -env WAZUH_INDEXER_SECRET 2>/dev/null \
            | grep -Eo '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$' \
            | tail -n 1
    )
    [ -n "${_hp_digest}" ] || return 1
    printf '%s' "${_hp_digest}"
}

# Replace one ${NAME} placeholder with its digest. index/substr rather than a regex, so that
# neither the placeholder nor the digest -- which contains '$', '/' and '.' -- is ever interpreted
# as a pattern or a replacement escape. The digest reaches awk through the environment, not argv.
#
# The result is written back through the original file rather than moved over it, so the ownership
# and mode the package set are preserved.
substitute_placeholder() {
    _sp_var="$1"
    _sp_file="$3"

    # This runs as root over a directory the service account owns, so the target
    # must be a regular file.
    if [ -L "${_sp_file}" ] || [ ! -f "${_sp_file}" ]; then
        err "refusing to write ${_sp_file}: not a regular file"
        return 1
    fi

    _sp_tmp=$(mktemp "${_sp_file}.XXXXXX") || return 1

    WAZUH_INDEXER_DIGEST="$2" awk -v var="${_sp_var}" '
        {
            placeholder = "${" var "}"
            position = index($0, placeholder)
            if (position > 0) {
                $0 = substr($0, 1, position - 1) \
                     ENVIRON["WAZUH_INDEXER_DIGEST"] \
                     substr($0, position + length(placeholder))
            }
            print
        }
    ' "${_sp_file}" > "${_sp_tmp}" || { rm -f "${_sp_tmp}"; return 1; }

    # cat, not mv: writing through the existing file keeps its inode, ownership
    # and mode. A mv would hand it mktemp's 0600 and this script's ownership.
    cat "${_sp_tmp}" > "${_sp_file}" || { rm -f "${_sp_tmp}"; return 1; }
    rm -f "${_sp_tmp}"
}

# The inverse of substitute_placeholder: put ${NAME} back where a digest was written, so the entry
# is once again the one the package shipped. Only --clear does this.
#
# It rewrites the whole hash line inside the account's block rather than searching for the digest,
# because by then the digest is the one thing we cannot name: it was derived from a password the
# credentials file no longer holds. Same guards as the forward direction -- a regular file only,
# written through the original inode so the ownership and mode the package set survive.
restore_placeholder() {
    _rp_account="$1"
    _rp_var="$2"
    _rp_file="$3"

    if [ -L "${_rp_file}" ] || [ ! -f "${_rp_file}" ]; then
        err "refusing to write ${_rp_file}: not a regular file"
        return 1
    fi

    # Already the shipped form: never resolved, or cleared before.
    grep -qF "hash: \"\${${_rp_var}}\"" "${_rp_file}" && return 0

    _rp_tmp=$(mktemp "${_rp_file}.XXXXXX") || return 1

    awk -v key="${_rp_account}" -v var="${_rp_var}" '
        substr($0, 1, length(key) + 1) == key ":" { inblock = 1; seen = 1; print; next }
        /^[^[:space:]]/ { inblock = 0 }
        inblock && /^[[:space:]]*hash:[[:space:]]/ {
            match($0, /^[[:space:]]*/)
            print substr($0, 1, RLENGTH) "hash: \"${" var "}\""
            restored = 1
            next
        }
        { print }
        END { if (!seen) exit 3; if (!restored) exit 1 }
    ' "${_rp_file}" > "${_rp_tmp}"
    _rp_status=$?

    # 3: no such account in this build. Nothing was ever resolved into it, so nothing to undo.
    if [ "${_rp_status}" -eq 3 ]; then
        rm -f "${_rp_tmp}"
        return 0
    fi
    if [ "${_rp_status}" -ne 0 ]; then
        rm -f "${_rp_tmp}"
        err "could not rewrite the ${_rp_account} entry of ${_rp_file}"
        return 1
    fi

    cat "${_rp_tmp}" > "${_rp_file}" || { rm -f "${_rp_tmp}"; return 1; }
    rm -f "${_rp_tmp}"
}

# Writing the digest into internal_users.yml is what "the internal users are initialised" means:
# the accounts exist in this node's own security configuration, with passwords only this
# installation has.
#
# Loading that configuration into the cluster is a separate, MANUAL step -- indexer-security-init.sh
# -- and it cannot be automated from here. A package knows nothing about the cluster it is joining:
# whether more nodes are still to be installed on other machines, or whether one of them has
# already uploaded a configuration that the .opendistro_security index now holds. Running it
# automatically would either race those nodes or overwrite what they uploaded.
write_user_hash() {
    _wuh_key="$1"

    if [ ! -f "${INTERNAL_USERS}" ]; then
        err "cannot write ${_wuh_key}: ${INTERNAL_USERS} is missing"
        return 1
    fi

    # Already substituted on an earlier run of this same installation -- in which case the value
    # being written is the one that run published, so the digest already in the file is its digest
    # -- or an account this build does not ship. The third way to get here, a digest with nothing
    # supplying its password any more, is caught by the caller before anything is generated.
    grep -q "\${${_wuh_key}}" "${INTERNAL_USERS}" || return 0

    _wuh_digest=$(hash_password "$2") || {
        err "could not hash ${_wuh_key} with ${SECURITY_TOOLS}/hash.sh"
        return 1
    }

    substitute_placeholder "${_wuh_key}" "${_wuh_digest}" "${INTERNAL_USERS}" || {
        err "could not write the ${_wuh_key} digest into ${INTERNAL_USERS}"
        _wuh_digest=""
        return 1
    }

    _wuh_digest=""
    log "wrote the ${_wuh_key} digest into internal_users.yml"
}

resolve_internal_users() {
    for _riu_key in ${OWNED_KEYS}; do
        _riu_status=0
        _riu_value=$(setting_get "${_riu_key}") || _riu_status=$?

        if [ "${_riu_status}" -eq 2 ]; then
            mark_unresolved "${_riu_key}"
            continue
        fi

        if [ "${_riu_status}" -eq 0 ]; then
            # An invalid value stops here rather than falling through to generation: replacing what
            # the operator asked for would discard their intent silently and leave this node
            # holding a credential nobody else has.
            if ! password_is_valid "${_riu_value}"; then
                err "${_riu_key} was rejected by the password policy"
                mark_invalid "${_riu_key}"
                continue
            fi
            log "using the supplied ${_riu_key}"
        else
            # We own the account, so generating the value makes it true -- but only while the
            # digest side can still be written. A digest with nothing supplying its password is a
            # credential whose two halves were separated; generating here would publish a password
            # that authenticates against nothing. The key is skipped rather than failed, because
            # that digest still works for whoever set it: an upgrade from a version predating this
            # mechanism arrives exactly like this.
            if ! placeholder_is_pending "${_riu_key}"; then
                err "${_riu_key}: internal_users.yml already holds a digest and nothing supplies the password"
                err "        leaving both alone: this node keeps the credential it has, nothing is published"
                err "        for the other components, and this run still records the installation as"
                err "        resolved, so the warning is not repeated. To resolve it from nothing, stop the"
                err "        service and run ${DIR}/bin/resolve-credentials.sh --clear; to set a password,"
                err "        use ${DIR}/tools/wazuh-passwords-tool.sh"
                continue
            fi

            _riu_value=$(wazuh_password_generate) || {
                err "could not generate ${_riu_key}"
                mark_unresolved "${_riu_key}"
                continue
            }
            log "generated ${_riu_key}"
        fi

        # A component publishes every credential it owns, whether it generated the value or was
        # given one, so a sibling installed later finds it. The manager reads
        # WAZUH_INDEXER_MANAGER_PASSWORD from here and the dashboard reads
        # WAZUH_INDEXER_KIBANASERVER_PASSWORD; publishing only generated values would mean a
        # deployment that chose its own passwords silently never hands them over.
        if ! wazuh_env_set "${_riu_key}" "${_riu_value}"; then
            err "could not publish ${_riu_key}"
            mark_unresolved "${_riu_key}"
            continue
        fi
        log "published ${_riu_key}"

        if ! write_user_hash "${_riu_key}" "${_riu_value}"; then
            mark_unresolved "${_riu_key}"
        fi
        _riu_value=""
    done

    [ -z "${UNRESOLVED}" ] && [ -z "${INVALID}" ]
}

# -----------------------------------------------------------------------------------------
# Owned: this node's certificates
# -----------------------------------------------------------------------------------------

# Who this node claims to be. WAZUH_INDEXER_CERT_SANS replaces the derived list wholesale rather
# than extending it, so an operator who sets it gets exactly what they asked for. Loopback is
# always appended regardless, because indexer-security-init.sh and wazuh-passwords-tool.sh connect
# to localhost.
derive_sans() {
    if [ -n "${WAZUH_INDEXER_CERT_SANS-}" ]; then
        _ds_sans="${WAZUH_INDEXER_CERT_SANS}"
    else
        _ds_sans=""
        _ds_short=$(hostname -s 2>/dev/null)
        _ds_fqdn=$(hostname -f 2>/dev/null)

        [ -n "${_ds_short}" ] && _ds_sans="DNS:${_ds_short}"
        if [ -n "${_ds_fqdn}" ] && [ "${_ds_fqdn}" != "${_ds_short}" ]; then
            _ds_sans="${_ds_sans:+${_ds_sans},}DNS:${_ds_fqdn}"
        fi

        # Global addresses on default-route interfaces only. Without that filter a host running
        # containers advertises docker0, veth* and CNI addresses too. The filter is a heuristic;
        # WAZUH_INDEXER_CERT_SANS is the escape hatch for when it guesses wrong.
        for _ds_iface in $(ip -o route show default 2>/dev/null | awk '{print $5}' | sort -u); do
            for _ds_addr in $(ip -o addr show dev "${_ds_iface}" scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1); do
                _ds_sans="${_ds_sans:+${_ds_sans},}IP:${_ds_addr}"
            done
        done
    fi

    for _ds_required in DNS:localhost IP:127.0.0.1 IP:::1; do
        case ",${_ds_sans}," in
            *",${_ds_required},"*) ;;
            *) _ds_sans="${_ds_sans:+${_ds_sans},}${_ds_required}" ;;
        esac
    done

    printf '%s' "${_ds_sans}"
}

issue_certificate() {
    _ic_name="$1"
    _ic_subject="$2"
    _ic_sans="$3"
    _ic_ca="$4"

    _ic_work=$(mktemp -d "${TMPDIR:-/tmp}/wazuh-indexer-certs.XXXXXX") || return 1
    chmod 700 "${_ic_work}"

    (
        umask 077
        openssl genrsa -out "${_ic_work}/key-temp.pem" 2048 2>/dev/null &&
        openssl pkcs8 -inform PEM -outform PEM -in "${_ic_work}/key-temp.pem" \
            -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "${_ic_work}/${_ic_name}-key.pem" 2>/dev/null
    ) || { rm -rf -- "${_ic_work}"; return 1; }

    openssl req -new -key "${_ic_work}/${_ic_name}-key.pem" -subj "${_ic_subject}" \
        -out "${_ic_work}/req.csr" 2>/dev/null || { rm -rf -- "${_ic_work}"; return 1; }

    printf 'subjectAltName = %s\n' "${_ic_sans}" > "${_ic_work}/req.ext"

    openssl x509 -req -in "${_ic_work}/req.csr" \
        -CA "${_ic_ca}/root-ca.pem" -CAkey "${_ic_ca}/root-ca.key" -CAcreateserial \
        -sha256 -out "${_ic_work}/${_ic_name}.pem" -days 3650 \
        -extfile "${_ic_work}/req.ext" 2>/dev/null || { rm -rf -- "${_ic_work}"; return 1; }

    install -m 0400 "${_ic_work}/${_ic_name}-key.pem" "${CERTS_DIR}/${_ic_name}-key.pem" &&
    install -m 0400 "${_ic_work}/${_ic_name}.pem" "${CERTS_DIR}/${_ic_name}.pem"
    _ic_status=$?

    rm -rf -- "${_ic_work}"
    return ${_ic_status}
}

# The certificate's subject in the form the security plugin compares against.
subject_of() {
    [ -f "$1" ] || return 0
    openssl x509 -in "$1" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//'
}

# The DN settings in opensearch.yml, one of three actions per key: "set" writes the value, "clear"
# leaves the key with no value, "keep" leaves it exactly as it is. Each key is reprinted without
# whatever followed it, which handles both the block style opensearch.prod.yml ships and the inline
# flow style of the upstream demo configuration.
set_distinguished_names() {
    _sdn_node_action="$1"
    _sdn_node="$2"
    _sdn_admin_action="$3"
    _sdn_admin="$4"

    [ -f "${CONFIG_FILE}" ] || return 0
    if [ -L "${CONFIG_FILE}" ]; then
        err "refusing to write ${CONFIG_FILE}: not a regular file"
        return 1
    fi

    _sdn_tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1

    WAZUH_NODE_DN="${_sdn_node}" WAZUH_ADMIN_DN="${_sdn_admin}" \
    awk -v node_action="${_sdn_node_action}" -v admin_action="${_sdn_admin_action}" '
        function emit(key, action, value) {
            print key ":"
            if (action == "set") print "- \"" value "\""
            skip = 1
        }
        /^plugins\.security\.nodes_dn[[:space:]]*:/ {
            if (node_action == "keep") { skip = 0; print; next }
            emit("plugins.security.nodes_dn", node_action, ENVIRON["WAZUH_NODE_DN"])
            next
        }
        /^plugins\.security\.authcz\.admin_dn[[:space:]]*:/ {
            if (admin_action == "keep") { skip = 0; print; next }
            emit("plugins.security.authcz.admin_dn", admin_action, ENVIRON["WAZUH_ADMIN_DN"])
            next
        }
        skip && /^[[:space:]]*#?[[:space:]]*-[[:space:]]/ { next }
        { skip = 0; print }
    ' "${CONFIG_FILE}" > "${_sdn_tmp}" || { rm -f "${_sdn_tmp}"; return 1; }

    # Written back through the original file rather than moved over it, so the mode and ownership
    # the package set survive.
    cat "${_sdn_tmp}" > "${CONFIG_FILE}" || { rm -f "${_sdn_tmp}"; return 1; }
    rm -f "${_sdn_tmp}"
    chown wazuh-indexer:wazuh-indexer "${CONFIG_FILE}" 2>/dev/null || true
}

# True when the setting carries no value: nothing after the colon and no list item under it.
# A key that is not in the file at all is not empty -- there is nothing to fill.
dn_is_empty() {
    [ "$(awk -v key="$1" '
        substr($0, 1, length(key) + 1) == key ":" {
            rest = substr($0, length(key) + 2)
            gsub(/[[:space:]]/, "", rest)
            state = (rest == "") ? "empty" : "filled"
            if (state == "filled") exit
            next
        }
        state == "empty" {
            if ($0 ~ /^[[:space:]]*#?[[:space:]]*-[[:space:]]/) state = "filled"
            exit
        }
        END { print state }
    ' "${CONFIG_FILE}")" = "empty" ]
}

# A node whose DN is not listed is rejected by the cluster, so the DN of the certificate has to
# reach the configuration in the same step that resolves it.
#
# Only --install replaces a key that already has a value. Every other mode fills the empty keys the
# package ships and leaves the rest alone, because by then the list may be the operator's own: one
# entry per node of their cluster.
write_distinguished_names() {
    [ -f "${CERTS_DIR}/indexer.pem" ] || return 0
    [ -f "${CONFIG_FILE}" ] || return 0

    _wdn_node=$(subject_of "${CERTS_DIR}/indexer.pem")
    [ -n "${_wdn_node}" ] || return 0
    _wdn_admin=$(subject_of "${CERTS_DIR}/admin.pem")

    _wdn_node_action="set"
    _wdn_admin_action="set"
    [ -n "${_wdn_admin}" ] || _wdn_admin_action="keep"

    if [ "${MODE}" != "install" ]; then
        dn_is_empty "plugins.security.nodes_dn" || _wdn_node_action="keep"
        dn_is_empty "plugins.security.authcz.admin_dn" || _wdn_admin_action="keep"
    fi

    [ "${_wdn_node_action}" = "set" ] || [ "${_wdn_admin_action}" = "set" ] || return 0

    set_distinguished_names "${_wdn_node_action}" "${_wdn_node}" \
                            "${_wdn_admin_action}" "${_wdn_admin}" || return 1

    [ "${_wdn_node_action}" = "set" ] && log "node DN ${_wdn_node}"
    [ "${_wdn_admin_action}" = "set" ] && log "admin DN ${_wdn_admin}"
    return 0
}

# The bundled JDK has to trust the Wazuh CA. This lives here rather than in the maintainer
# scripts so that a pair staged after the install reaches the truststore too, and so --clear can
# take it back. LC_ALL=C because keytool's localized prompts are not all usable; -storepass and
# -noprompt because there is nobody to answer them.
TRUSTSTORE="${DIR}/jdk/lib/security/cacerts"
TRUSTSTORE_ALIAS="wazuh-root-ca"

keytool_run() {
    [ -x "${DIR}/jdk/bin/keytool" ] && [ -f "${TRUSTSTORE}" ] || return 1
    LC_ALL=C "${DIR}/jdk/bin/keytool" -keystore "${TRUSTSTORE}" -storepass changeit -noprompt "$@"
}

trust_ca() {
    [ -f "${CERTS_DIR}/root-ca.pem" ] || return 0

    # Re-importing over an existing alias is an error, so the old one goes first.
    keytool_run -delete -alias "${TRUSTSTORE_ALIAS}" > /dev/null 2>&1
    if keytool_run -importcert -trustcacerts -alias "${TRUSTSTORE_ALIAS}" \
            -file "${CERTS_DIR}/root-ca.pem" > /dev/null 2>&1; then
        log "trusted the CA in the bundled JDK truststore"
    else
        err "could not import ${CERTS_DIR}/root-ca.pem into ${TRUSTSTORE}"
    fi
}

untrust_ca() {
    if keytool_run -delete -alias "${TRUSTSTORE_ALIAS}" > /dev/null 2>&1; then
        log "removed the CA from the bundled JDK truststore"
    fi
}

# True when every certificate staged in CERTS_DIR was issued by the anchor in $1. Each file is also
# passed as -untrusted, so a certificate that carries its intermediate CAs verifies too. Expiry is
# not this check's business.
pair_issued_by() {
    for _pi in indexer admin; do
        [ -f "${CERTS_DIR}/${_pi}.pem" ] || continue
        openssl verify -no_check_time -CAfile "$1" -untrusted "${CERTS_DIR}/${_pi}.pem" \
            "${CERTS_DIR}/${_pi}.pem" > /dev/null 2>&1 || return 1
    done
    return 0
}

# The four cases are decided entirely by what is present, with no mode flag: the presence of a
# private key beside the anchor is the signal, so a host never given one cannot sign and cannot be
# where a CA key leaks from.
#
#   A  nothing in the CA directory        mint a bootstrap CA, then self-issue
#   B  anchor and key                     issue from the CA found
#   C  pair already staged                use it, generate nothing -- once it is known to chain to
#                                         the anchor
#   D  anchor only, no pair               unresolved; nothing can be invented
resolve_certificates() {
    _rc_ca=$(wazuh_ca_get_dir) || {
        err "no CA directory"
        return 1
    }

    mkdir -p "${CERTS_DIR}"

    # C: an operator staged an issued pair, or a purge kept one. A pair the anchor did not issue
    # would leave the node unable to complete a handshake while the resolution reports success, so
    # it is checked first. The anchor is the CA directory's; with nothing there, the copy staged
    # beside the pair, and no CA is minted: a new one could not have issued it.
    if [ -f "${CERTS_DIR}/indexer.pem" ] && [ -f "${CERTS_DIR}/indexer-key.pem" ]; then
        if [ -e "${_rc_ca}/root-ca.pem" ] || [ -e "${_rc_ca}/root-ca.key" ]; then
            if ! wazuh_ca_ensure; then
                err "the CA directory could not be prepared"
                return 1
            fi
            _rc_anchor="${_rc_ca}/root-ca.pem"
        else
            _rc_anchor="${CERTS_DIR}/root-ca.pem"
        fi

        if [ ! -f "${_rc_anchor}" ]; then
            err "a certificate pair is staged in ${CERTS_DIR}, but no CA certificate to verify it"
            err "        stage the root-ca.pem that issued it into ${_rc_ca}"
            return 1
        fi
        if ! pair_issued_by "${_rc_anchor}"; then
            err "the certificate pair in ${CERTS_DIR} was not issued by ${_rc_anchor}"
            err "        stage the CA that issued it, or remove the pair so that this node issues a new one"
            return 1
        fi

        # root-ca.pem mode is 0400 and service-owned.
        if [ "${_rc_anchor}" != "${CERTS_DIR}/root-ca.pem" ]; then
            install -m 0400 "${_rc_anchor}" "${CERTS_DIR}/root-ca.pem"
            chown wazuh-indexer:wazuh-indexer "${CERTS_DIR}/root-ca.pem" 2>/dev/null || true
        fi

        log "found an issued certificate pair in ${CERTS_DIR}; generating nothing"
        write_distinguished_names
        return 0
    fi

    if ! wazuh_ca_ensure; then
        err "the CA directory could not be prepared"
        return 1
    fi

    # root-ca.pem mode is 0400 and service-owned.
    if [ -f "${_rc_ca}/root-ca.pem" ]; then
        install -m 0400 "${_rc_ca}/root-ca.pem" "${CERTS_DIR}/root-ca.pem"
        chown wazuh-indexer:wazuh-indexer "${CERTS_DIR}/root-ca.pem" 2>/dev/null || true
    fi

    # D: a trust anchor but no way to sign and no pair.
    if [ ! -f "${_rc_ca}/root-ca.key" ]; then
        err "${_rc_ca}/root-ca.pem carries no signing key and no issued pair is staged in ${CERTS_DIR}"
        return 1
    fi

    _rc_short=$(hostname -s 2>/dev/null)
    [ -n "${_rc_short}" ] || _rc_short="wazuh-indexer"
    _rc_sans=$(derive_sans)
    # wazuh-certs-tool issues with this same RDN order, so a deployment that later replaces these
    # with the tool's own certificates keeps the DNs already written into opensearch.yml valid.
    _rc_suffix="/OU=Wazuh/O=Wazuh/L=California/C=US"

    issue_certificate "indexer" "/CN=${_rc_short}${_rc_suffix}" "${_rc_sans}" "${_rc_ca}" || {
        err "could not issue the node certificate"
        return 1
    }
    issue_certificate "admin" "/CN=admin${_rc_suffix}" "DNS:localhost" "${_rc_ca}" || {
        err "could not issue the admin certificate"
        return 1
    }

    chown -R wazuh-indexer:wazuh-indexer "${CERTS_DIR}" 2>/dev/null || true

    # A wrong name fails only at the first peer connection, not here, so log what this node
    # presents.
    log "issued indexer.pem: CN=${_rc_short}; SANs ${_rc_sans}"

    write_distinguished_names
    return 0
}

# -----------------------------------------------------------------------------------------
# --clear
#
# The one destructive path, for an image built by installing the package. Two things it does not
# remove: a CA directory holding only an anchor, which was issued elsewhere, and anything outside
# the managed block of the credentials file.
# -----------------------------------------------------------------------------------------

# The pidfile plus kill -0, using only builtins. pgrep would have been shorter but it lives in
# procps-ng, which a minimal image need not carry -- and a guard that silently answers "not
# running" because its binary is absent is worse than no guard at all on the one path in this
# script that destroys credentials.
indexer_is_running() {
    for _iir_pid in "${PID_DIR}"/*.pid; do
        [ -e "${_iir_pid}" ] || continue
        _iir_n=$(cat "${_iir_pid}" 2>/dev/null)
        [ -n "${_iir_n}" ] || continue
        # A stale pidfile from an unclean stop is not a running node.
        kill -0 "${_iir_n}" 2>/dev/null && return 0
    done
    return 1
}

# A digest in internal_users.yml and the password in the credentials file are one credential in two
# halves. Taking back only the published half is what leaves a node holding new passwords and the
# old digests: the next resolution generates, publishes, finds no placeholder to write into, and
# says nothing, because a missing placeholder is also how an account this build does not ship looks.
restore_internal_users() {
    if [ ! -f "${INTERNAL_USERS}" ]; then
        log "no ${INTERNAL_USERS}; no digests to take back"
        return 0
    fi

    _ciu_failed=""
    for _ciu_key in ${OWNED_KEYS}; do
        _ciu_account=$(account_for "${_ciu_key}") || continue
        restore_placeholder "${_ciu_account}" "${_ciu_key}" "${INTERNAL_USERS}" \
            || _ciu_failed="${_ciu_failed} ${_ciu_account}"
    done

    if [ -n "${_ciu_failed}" ]; then
        err "could not restore the placeholders for:${_ciu_failed}"
        return 1
    fi

    log "restored the password placeholders in internal_users.yml"
}

clear_credentials() {
    if indexer_is_running; then
        err "refusing to clear credentials while the indexer is running"
        err "        stop it first: systemctl stop wazuh-indexer"
        return 1
    fi

    # First, and fatal. Everything else here is a removal, and a removal that half-completed can
    # simply be run again; this cannot. Once the published passwords are gone, nothing is left to
    # say which passwords the digests belong to. So if the digests cannot be taken back, nothing
    # else is touched either.
    if ! restore_internal_users; then
        err "        nothing was cleared; fix the file above and run --clear again"
        return 1
    fi

    if [ -e "${MARKER}" ]; then
        rm -f -- "${MARKER}"
        log "removed the initialisation marker; the next start re-initialises the security configuration"
    fi

    for _cc_file in indexer.pem indexer-key.pem admin.pem admin-key.pem root-ca.pem; do
        if [ -e "${CERTS_DIR}/${_cc_file}" ]; then
            rm -f -- "${CERTS_DIR}/${_cc_file}"
            log "removed certs/${_cc_file}"
        fi
    done

    _cc_ca=$(wazuh_ca_get_dir 2>/dev/null) || _cc_ca=""
    if [ -n "${_cc_ca}" ] && [ -f "${_cc_ca}/root-ca.key" ]; then
        rm -f -- "${_cc_ca}/root-ca.pem" "${_cc_ca}/root-ca.key" "${_cc_ca}/root-ca.srl"
        log "removed the bootstrap CA in ${_cc_ca}"
    elif [ -n "${_cc_ca}" ] && [ -f "${_cc_ca}/root-ca.pem" ]; then
        log "keeping the trust anchor in ${_cc_ca}: it carries no private key, so it was issued elsewhere"
    fi

    untrust_ca

    # The DNs are derived from certificates that are now gone. Left behind, they would be the only
    # thing an image built this way still carries from the build host -- and the rule above, which
    # fills empty keys only, would never replace them.
    if set_distinguished_names "clear" "" "clear" ""; then
        log "cleared the node and admin DNs in opensearch.yml"
    fi

    # Only this component's keys, and only inside the managed block.
    for _cc_key in ${OWNED_KEYS}; do
        wazuh_env_unset "${_cc_key}" >/dev/null 2>&1 || true
    done
    log "removed the indexer's published keys from the credentials file"

    log "cleared; the next start resolves the passwords and the certificates again"
    # The cluster keeps the configuration it was last given, so on a node that has already been
    # initialised the new digests are only local until someone uploads them.
    log "        a cluster already holding the previous configuration takes the new passwords from"
    log "        ${DIR}/bin/indexer-security-init.sh, once the node is up"
    return 0
}

# -----------------------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------------------

if [ "${MODE}" = "clear" ]; then
    clear_credentials
    exit $?
fi

# Resolution happens once. Everything below this point is skipped for the whole life of the
# installation once the marker exists, which is what stops a restart or an upgrade from touching
# credentials or certificates an operator has since changed. --clear is the only way back.
if resolution_is_complete; then
    # One exception: the truststore is a packaged file, so installing the package over an existing
    # one replaces it and takes the CA entry with it. Re-importing needs nothing resolved and is
    # idempotent.
    case "${MODE}" in
        install|upgrade) trust_ca ;;
    esac
    log "already initialised; nothing is resolved again"
    exit 0
fi

resolve_internal_users

# The certificate step runs in every mode, because the marker above is what makes resolution happen
# once. A run that reaches this point is a run where it never completed, so a pair staged after an
# install that could not issue one is picked up by the next start.
if resolve_certificates; then
    CERTIFICATES_RESOLVED=1
    trust_ca
else
    CERTIFICATES_RESOLVED=0
    err "the indexer has no usable TLS certificates and this run could not issue them"
    err "        stage the pair into ${CERTS_DIR} before starting the service"
    err "        (e.g. with wazuh-certs-tool); the service will not start without it"
fi

# Record completion only on a run that resolved everything it was responsible for. A node left with
# an unresolved key or a rejected value gets another chance on the next start; one that is fully
# resolved is never examined again.
if [ -z "${UNRESOLVED}" ] && [ -z "${INVALID}" ] && [ "${CERTIFICATES_RESOLVED}" = "1" ]; then
    mark_complete
fi

# The installer has no opinion about whether the component can run: no warning, no failure, no
# special state. Nothing checks credentials until something needs them.
if [ "${MODE}" = "install" ] || [ "${MODE}" = "upgrade" ]; then
    exit 0
fi

if [ -z "${UNRESOLVED}" ] && [ -z "${INVALID}" ] && [ "${CERTIFICATES_RESOLVED}" = "1" ]; then
    exit 0
fi

CREDENTIALS_FILE=$(wazuh_env_get_file 2>/dev/null) || CREDENTIALS_FILE="/etc/wazuh/credentials.env"

# The message goes to the journal, which is where someone looks when a service will not start.
# It names every missing key and where to set it, and never prints a value.
for _key in ${INVALID}; do
    err "INVALID ${_key}: the supplied value does not meet the password policy"
    err "        (12-64 characters from A-Z a-z 0-9 . , _ + : @ % ^ = ~ -, with at least one letter and one digit)"
    err "        correct it in ${CREDENTIALS_FILE} and start the service again"
done

for _key in ${UNRESOLVED}; do
    err "MISSING ${_key}"
    err "        set it in ${CREDENTIALS_FILE}"
done

if [ "${CERTIFICATES_RESOLVED}" != "1" ]; then
    err "MISSING TLS certificates"
    err "        stage indexer.pem and indexer-key.pem in ${CERTS_DIR}"
fi

exit 1
