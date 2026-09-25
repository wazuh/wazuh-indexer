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
# The shared half -- the credentials file, its locking convention, password generation and
# validation, and the CA -- lives in wazuh-credentials.sh, which the manager, the indexer and the
# dashboard must agree on exactly. It is owned by wazuh-installation-assistant and is downloaded
# into lib/ by build-scripts/assemble.sh; it is NOT in this repository.
#
# This file adds only what is specific to the indexer: which keys it owns, which it consumes, and
# where each resolved value is stored. The interface is the one every component shares, so an
# operator, an image build or a playbook drives all three the same way.
#
# The indexer is the simplest of the three: it OWNS all three of its accounts and CONSUMES none.
# A password can therefore never be unresolved here -- generating it is what makes it true. Only a
# certificate can be unresolved, and only in the one case where a host was handed a trust anchor
# but no signing key and no issued pair, so it has no way to obtain an identity.
#
# RESOLUTION HAPPENS ONCE. A run that resolves everything it was responsible for records the fact
# in a marker file, and every later run exits immediately without reading a key, a certificate or
# the credentials file. This is not an optimisation: a password an operator rotated, or a
# certificate pair they replaced with their own, must survive a service restart and a package
# upgrade, and the only way to guarantee that is to stop looking. --clear is the one way back.
#
# The same script runs at four moments:
#
#   --install    From a FRESH postinst / %post -- never from an upgrade. Creates what it can, and
#                has no opinion about whether the indexer can run. Never fails: a maintainer script
#                that aborts leaves the package half-configured, breaks `apt install -f` and fails
#                image builds. Exits 0 whatever it could not resolve. This is the only moment that
#                issues TLS certificates.
#
#   --upgrade    From postinst / %post when a previous version was already installed. A no-op on
#                any host that has already completed resolution; on one upgrading from a version
#                that predates this mechanism it fills in the passwords that host never had. It
#                does NOT touch the certificates in either case.
#
#   --prestart   From the unit's ExecStartPre. A no-op on any host that has already completed
#                resolution. Otherwise it runs the ladder again, not merely a check, so a node
#                installed before anything else picks up what became available since, and exits
#                non-zero naming every key it could not resolve. Like --upgrade it does not touch
#                the certificates.
#
#   --clear      Removes every credential this indexer owns or stores, so the next --install or
#                --prestart resolves from nothing. Nothing in the product calls it: it exists for
#                an image built by installing the package, whose postinst therefore published this
#                host's passwords, minted a bootstrap CA and issued certificates into the image
#                layer. Every container started from such an image would otherwise share one CA
#                private key and one set of passwords -- worse than the defect this mechanism
#                closes, because it looks random. Run it at the end of the Dockerfile, or once from
#                an entrypoint before the first start.
#
# Certificates are issued at install and never looked at again, for the same reason they are in the
# manager: resolving them is not a lookup but a signature, so every later run would have to
# re-derive the trust chain and would turn the shared CA directory into a standing dependency. A
# deployment that brings its own PKI stages a pair and keeps no copy of its root CA on every node
# forever. What the node will actually accept is decided by the security plugin against the files
# as they are at start, which is the only state that matters.
#
# The step never opens a network connection. It validates presence and format only -- making a
# service's start depend on reaching its peer would break boot ordering and cluster restarts.
# A credential that is present but wrong still fails as a 401 at runtime.
#

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

# Step 0 for the whole run, and the single thing that makes this tool safe to leave wired into a
# service start. It records that this installation has resolved its credentials and its TLS
# material, and once it exists nothing is resolved again -- not on a restart, not on an upgrade,
# not on a reinstall of the same version.
#
# That is what protects an operator who changed a password or staged their own certificate pair
# after installation: without the marker the next service start would resolve from whatever the
# credentials file says now, and a file that has since been deleted -- which is the documented last
# step of an installation -- would mean generating a fresh password the cluster does not know.
#
# It holds no secret. internal_users.yml cannot be the test -- it ships with the package, so every
# upgrade and every restart would be a coin toss.
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

# Process environment, then the credentials file. The environment wins because it is the more
# deliberate and more immediate input, and because an orchestrator setting a value should not be
# silently overridden by a file left behind from an earlier install.
#
# An explicitly empty value is treated as absent rather than as a policy failure: for a password
# that is what an operator who cleared a line means.
#
# Prints the value and returns 0 when set, 1 when absent, 2 when the file itself is unusable.
# The wazuh-docker names that predate the scoped ones, accepted from the ENVIRONMENT ONLY.
# Renaming them would break existing compose files. They cannot be read from the credentials file:
# an unscoped DASHBOARD_PASSWORD is workable as a per-process variable but meaningless as a line in
# a file three components read, and the ambiguity never arises in a container because a container
# reads only its own environment.
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
# admin, kibanaserver and wazuh-manager all live in internal_users.yml, whose shipped hashes are
# ${NAME} placeholders. Each value is resolved, published to the credentials file so the manager
# and the dashboard find it, and written here as a bcrypt digest. Loading the result into the
# cluster is the operator's separate, manual step.
#
# Nothing here is consumed, so nothing here can reach step 3.
# -----------------------------------------------------------------------------------------

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
    ' "${_sp_file}" > "${_sp_file}.tmp" || { rm -f "${_sp_file}.tmp"; return 1; }

    cat "${_sp_file}.tmp" > "${_sp_file}" || { rm -f "${_sp_file}.tmp"; return 1; }
    rm -f "${_sp_file}.tmp"
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

    # Already substituted on an earlier run, or an account this build does not ship.
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
            # We own the account, so generating the value makes it true.
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

# A node whose DN is not listed is rejected by the cluster, so the DN of the certificate just
# minted has to reach the configuration in the same step that mints it.
#
# Both keys are rewritten wholesale: the key line is reprinted without whatever followed it and the
# new entry written underneath. That covers the block style opensearch.prod.yml ships and the
# inline ['CN=...'] flow style the upstream demo configuration uses -- appending to the latter
# would produce a root-level sequence item after a mapping, which is not valid YAML.
write_distinguished_names() {
    [ -f "${CERTS_DIR}/indexer.pem" ] || return 0
    [ -f "${CONFIG_FILE}" ] || return 0

    _wdn_node=$(openssl x509 -in "${CERTS_DIR}/indexer.pem" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//')
    [ -n "${_wdn_node}" ] || return 0

    _wdn_admin=""
    if [ -f "${CERTS_DIR}/admin.pem" ]; then
        _wdn_admin=$(openssl x509 -in "${CERTS_DIR}/admin.pem" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//')
    fi

    WAZUH_NODE_DN="${_wdn_node}" WAZUH_ADMIN_DN="${_wdn_admin}" awk '
        BEGIN { skip = 0 }
        /^plugins\.security\.nodes_dn[[:space:]]*:/ {
            print "plugins.security.nodes_dn:"
            print "- \"" ENVIRON["WAZUH_NODE_DN"] "\""
            skip = 1
            next
        }
        /^plugins\.security\.authcz\.admin_dn[[:space:]]*:/ && ENVIRON["WAZUH_ADMIN_DN"] != "" {
            print "plugins.security.authcz.admin_dn:"
            print "- \"" ENVIRON["WAZUH_ADMIN_DN"] "\""
            skip = 1
            next
        }
        skip && /^[[:space:]]*#?[[:space:]]*-[[:space:]]/ { next }
        { skip = 0; print }
    ' "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"

    chown wazuh-indexer:wazuh-indexer "${CONFIG_FILE}" 2>/dev/null || true
    log "node DN ${_wdn_node}"
}

# The four cases are decided entirely by what is present, with no mode flag: the presence of a
# private key beside the anchor is the signal, so a host never given one cannot sign and cannot be
# where a CA key leaks from.
#
#   A  nothing in the CA directory        mint a bootstrap CA, then self-issue
#   B  anchor and key                     issue from the CA found
#   C  anchor only, pair already staged   use both, generate nothing
#   D  anchor only, no pair               unresolved; nothing can be invented
resolve_certificates() {
    _rc_ca=$(wazuh_ca_get_dir) || {
        err "no CA directory"
        return 1
    }

    if ! wazuh_ca_ensure; then
        err "the CA directory could not be prepared"
        return 1
    fi

    mkdir -p "${CERTS_DIR}"

    if [ -f "${_rc_ca}/root-ca.pem" ]; then
        install -m 0444 "${_rc_ca}/root-ca.pem" "${CERTS_DIR}/root-ca.pem"
    fi

    # C: an operator staged an issued pair before installing. That is step 0, which is why there is
    # no key for it.
    if [ -f "${CERTS_DIR}/indexer.pem" ] && [ -f "${CERTS_DIR}/indexer-key.pem" ]; then
        log "found an issued certificate pair in ${CERTS_DIR}; generating nothing"
        write_distinguished_names
        return 0
    fi

    # D: a trust anchor but no way to sign and no pair.
    if [ ! -f "${_rc_ca}/root-ca.key" ]; then
        err "${_rc_ca}/root-ca.pem carries no signing key and no issued pair is staged in ${CERTS_DIR}"
        return 1
    fi

    _rc_short=$(hostname -s 2>/dev/null)
    [ -n "${_rc_short}" ] || _rc_short="wazuh-indexer"
    _rc_sans=$(derive_sans)
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
# The one destructive path in a tool whose every other rule is "never overwrite, never repair,
# leave what is already there alone". It exists for an image built by installing the package, which
# ran the resolver in its postinst and therefore baked this host's credentials into a layer every
# container will share.
#
# Two things it deliberately does NOT remove:
#
#   * A CA directory holding only an anchor. No private key beside it means the CA was issued
#     elsewhere and handed to this host; it is not ours to destroy.
#   * Anything outside the managed block of the credentials file, or any sibling component's keys.
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

clear_credentials() {
    if indexer_is_running; then
        err "refusing to clear credentials while the indexer is running"
        err "        stop it first: systemctl stop wazuh-indexer"
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

    # Only this component's keys, and only inside the managed block.
    for _cc_key in ${OWNED_KEYS}; do
        wazuh_env_unset "${_cc_key}" >/dev/null 2>&1 || true
    done
    log "removed the indexer's published keys from the credentials file"

    log "cleared; the next start resolves from nothing"
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
    log "already initialised; nothing is resolved again"
    exit 0
fi

resolve_internal_users

# Certificates are issued once, on a fresh install, and are not part of the ladder at any other
# moment -- see the header. An upgrade that re-derived the chain would have to find the shared CA
# directory unchanged, which is exactly the standing dependency this design refuses to create.
if [ "${MODE}" = "install" ]; then
    # This is the only chance to issue them, so say so plainly rather than exiting 0 in silence and
    # letting the operator meet it later as a security plugin that will not load.
    if resolve_certificates; then
        CERTIFICATES_RESOLVED=1
    else
        CERTIFICATES_RESOLVED=0
        err "the indexer has no TLS certificates and this install could not issue them"
        err "        stage the pair into ${CERTS_DIR} before starting the service"
        err "        (e.g. with wazuh-certs-tool); the service will not start without it"
    fi
else
    # Not attempted, so not something this run can fail to resolve.
    CERTIFICATES_RESOLVED=1
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

if [ -z "${UNRESOLVED}" ] && [ -z "${INVALID}" ]; then
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

exit 1
