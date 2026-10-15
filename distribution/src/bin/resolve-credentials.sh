#!/bin/sh

# Copyright (C) 2026, Wazuh Inc.
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.
#
# The indexer's credential and TLS resolution.
#
# The other half -- the published credentials file, the CA, password generation and validation,
# and the file-trust rules -- lives in lib/wazuh-indexer-credentials.sh, which belongs to this
# package. Everything is under /etc/wazuh-indexer: what the indexer publishes for the manager and
# the dashboard on this host is in export/, its CA in ca/, and the operator's own values in
# local.env. Nothing is shared with another package.
#
# The indexer owns all three of its accounts and consumes none, so a password is never unresolved:
# generating it is what makes it true. Only a certificate can be, and only when the host was handed
# a trust anchor with no signing key and no issued pair.
#
# Resolution happens once. A run that resolves everything it was responsible for records the fact
# in a marker file, and every later run only checks the files -- which is what lets an operator
# rotate a password or stage their own certificates and keep them across restarts and upgrades.
# --clear is the way back. Modes:
#
#   --install    From a fresh postinst / %post. Never fails: a maintainer script that aborts leaves
#                the package half-configured. It is the only mode that replaces DN settings that
#                already have a value.
#   --upgrade    From postinst / %post over a previous version.
#   --prestart   From the unit's ExecStartPre and the SysV start. Checks the files first, on every
#                start, then exits non-zero naming whatever it could not resolve, so the service
#                does not start on a half-resolved or tampered node.
#   --check      The file checks alone: local.env, export/, ca/, certs/ and the configuration files
#                this script writes must be regular files owned by root that nobody else can write,
#                in directories with the same properties. One line per problem, exit 1 on any.
#   --clear      Takes back everything this component resolved, for images built by installing the
#                package. Nothing in the product calls it.
#
# -q|--quiet silences the progress lines; whatever could not be resolved still prints.
#
# Every mode resolves passwords, certificates and the JDK truststore entry while the marker is
# absent; the marker, not the mode, is what stops it happening twice. Nothing here opens a network
# connection: presence and format only. Nothing here runs a host tool but openssl, ip, getent and
# restorecon when present; everything else is a shell builtin or coreutils.
#
# The design behind all of this is documented in the development guide, "Credential and TLS
# resolution".

MODE="prestart"
DIR=""
QUIET=""

# ${1-} rather than $1, matching the helper's convention: the bare form is an "unbound variable"
# error under a caller that runs us with `set -u`, and `shift 2` on a lone -H is a hard error in
# dash rather than a diagnosable one.
while [ -n "${1-}" ]; do
    case "${1-}" in
        --install)  MODE="install" ; shift ;;
        --upgrade)  MODE="upgrade" ; shift ;;
        --prestart) MODE="prestart"; shift ;;
        --check)    MODE="check"   ; shift ;;
        --clear)    MODE="clear"   ; shift ;;
        -q|--quiet) QUIET="1"      ; shift ;;
        -H)
            if [ -z "${2-}" ]; then
                echo "resolve-credentials: -H needs a directory" >&2
                exit 2
            fi
            DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--install|--upgrade|--prestart|--check|--clear] [-q|--quiet] [-H <home>]"
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

# WAZUH_INDEXER_HELPER_DIR overrides where to look, which is what lets a test suite drive the
# ladder without an install. On an installed node the second branch wins and the rest never runs.
if [ -n "${WAZUH_INDEXER_HELPER_DIR-}" ] && [ -f "${WAZUH_INDEXER_HELPER_DIR}/wazuh-indexer-credentials.sh" ]; then
    HELPER_DIR="${WAZUH_INDEXER_HELPER_DIR}"
elif [ -f "${DIR}/lib/wazuh-indexer-credentials.sh" ]; then
    HELPER_DIR="${DIR}/lib"
elif [ -f "${_self_dir}/wazuh-indexer-credentials.sh" ]; then
    HELPER_DIR="${_self_dir}"
else
    echo "resolve-credentials: cannot find wazuh-indexer-credentials.sh" >&2
    echo "        it is shipped in ${DIR}/lib by the wazuh-indexer package" >&2
    exit 2
fi

. "${HELPER_DIR}/wazuh-indexer-credentials.sh"

CONFIG_DIR="${WAZUH_INDEXER_CONFIG_DIR-/etc/wazuh-indexer}"
SECURITY_CONFIG_DIR="${CONFIG_DIR}/opensearch-security"
INTERNAL_USERS="${SECURITY_CONFIG_DIR}/internal_users.yml"
SECURITY_TOOLS="${DIR}/plugins/opensearch-security/tools"
CONFIG_FILE="${CONFIG_DIR}/opensearch.yml"
CERTS_DIR="${CONFIG_DIR}/certs"
DATA_DIR="${WAZUH_INDEXER_DATA_DIR-/var/lib/wazuh-indexer}"
PID_DIR="${WAZUH_INDEXER_PID_DIR-/run/wazuh-indexer}"
EXPORT_DIR=$(wazuh_export_get_dir)
LOCAL_ENV=$(wazuh_local_env_file)
SERVICE_GROUP=$(wazuh_service_group)

# Records that this installation resolved its credentials and its TLS material. Once it exists
# nothing is resolved again, which is what protects an operator who rotated a password or staged
# their own certificates. It holds no secret, and internal_users.yml cannot take its place: that
# file ships with the package.
MARKER="${DATA_DIR}/.initialized"

OWNED_KEYS="WAZUH_INDEXER_ADMIN_PASSWORD WAZUH_INDEXER_KIBANASERVER_PASSWORD WAZUH_INDEXER_MANAGER_PASSWORD"

LOG_TAG="resolve-credentials"

# Progress. Silenced by --quiet, which the maintainer scripts use so that the install ends with
# its next-steps block rather than with a list of keys. Errors are never silenced.
log() {
    [ -z "${QUIET}" ] || return 0
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

# -----------------------------------------------------------------------------------------
# File checks
#
# What --check prints and --prestart runs first, on every start. The rules are the helper's: a
# regular file, not a symbolic link, owned by root, writable by nobody else, in a directory with
# the same properties. Nothing here is repaired: a path that fails is reported and the start is
# refused, because a repair would either hide a mistake or complete an attack.
# -----------------------------------------------------------------------------------------

CHECK_FAILED=0

check_failed() {
    CHECK_FAILED=1
}

# Every entry of a directory, dot files included.
check_entries() {
    for _ce in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [ -e "${_ce}" ] || [ -L "${_ce}" ] || continue
        if [ -d "${_ce}" ] && [ ! -L "${_ce}" ]; then
            wazuh_check_dir "${_ce}" || check_failed
        else
            wazuh_check_file "${_ce}" || check_failed
        fi
    done
}

# A directory that is allowed to be absent: present and trusted, or absent.
check_optional_dir() {
    wazuh_check_dir "$1"
    case $? in
        0) check_entries "$1" ;;
        2) check_failed ;;
    esac
}

check_files() {
    CHECK_FAILED=0

    wazuh_check_dir "${CONFIG_DIR}"
    case $? in
        1) err "MISSING ${CONFIG_DIR}"; check_failed ;;
        2) check_failed ;;
    esac

    # The operator's values: root's private file, and parseable.
    wazuh_check_secret "${LOCAL_ENV}"
    case $? in
        0) wazuh_env_check "${LOCAL_ENV}" || check_failed ;;
        2) check_failed ;;
    esac

    # What this package publishes: the passwords are root's private file, the CA certificate is
    # readable by the service group.
    check_optional_dir "${EXPORT_DIR}"
    wazuh_check_secret "${EXPORT_DIR}/credentials.env"
    case $? in
        0) wazuh_env_check "${EXPORT_DIR}/credentials.env" || check_failed ;;
        2) check_failed ;;
    esac

    # The CA: its key is root's private file, and the pair must be a CA that matches it.
    _cf_ca=$(wazuh_ca_get_dir)
    check_optional_dir "${_cf_ca}"
    wazuh_check_secret "${_cf_ca}/root-ca.key"
    case $? in
        2) check_failed ;;
    esac
    if [ -e "${_cf_ca}/root-ca.pem" ] || [ -L "${_cf_ca}/root-ca.pem" ] \
       || [ -e "${_cf_ca}/root-ca.key" ] || [ -L "${_cf_ca}/root-ca.key" ]; then
        if ! _cf_why=$(wazuh_ca_validate 2>&1 >/dev/null); then
            err "INVALID ${_cf_ca}: ${_cf_why#wazuh-indexer-credentials: }"
            check_failed
        fi
    fi

    # This node's certificates, and the configuration files this script writes.
    check_optional_dir "${CERTS_DIR}"
    check_optional_dir "${SECURITY_CONFIG_DIR}"
    for _cf_file in "${CONFIG_FILE}" "${INTERNAL_USERS}"; do
        wazuh_check_file "${_cf_file}"
        case $? in
            2) check_failed ;;
        esac
    done

    [ "${CHECK_FAILED}" -eq 0 ]
}

# -----------------------------------------------------------------------------------------
# Lookup
# -----------------------------------------------------------------------------------------

# The wazuh-docker names that predate the scoped ones, accepted from the environment only.
alias_for() {
    case "$1" in
        WAZUH_INDEXER_KIBANASERVER_PASSWORD) printf '%s' "DASHBOARD_PASSWORD" ;;
        *) return 1 ;;
    esac
}

# Process environment first, then local.env, then what this package already published: an
# orchestrator setting a value should not be overridden by a file, and the operator's file should
# not be overridden by an earlier publication. An empty value counts as absent. Prints the value
# and returns 0 when set, 1 when absent, 2 when a file is unusable.
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

    # The alias is an environment channel, so it still outranks the files.
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

# file_contains <text> <file> [start]: true when a line of <file> contains <text> literally, or
# starts with it when "start" is given.
file_contains() {
    [ -r "$2" ] || return 1
    while IFS= read -r _fc_line || [ -n "${_fc_line}" ]; do
        if [ "${3:-}" = start ]; then
            case "${_fc_line}" in "$1"*) return 0 ;; esac
        else
            case "${_fc_line}" in *"$1"*) return 0 ;; esac
        fi
    done < "$2"
    return 1
}

# The marker lives in the data directory, which the service account owns. A symbolic link put
# there in its place is not a marker, and never written through: completion is recorded by
# renaming a fresh file over whatever the entry is.
resolution_is_complete() {
    [ -f "${MARKER}" ] && [ ! -L "${MARKER}" ]
}

# Written only when everything this mode was responsible for came out resolved. A partial run must
# not record completion: an install that could not issue certificates has to be able to finish the
# job on the next one, and a marker written over a half-resolved node would make that impossible
# without manual intervention.
mark_complete() {
    [ -d "${DATA_DIR}" ] || mkdir -p "${DATA_DIR}" 2>/dev/null || return 0
    _mc_tmp=$(mktemp "${MARKER}.XXXXXX" 2>/dev/null) || {
        err "could not record completion in ${MARKER}; the next start would resolve again"
        return 1
    }
    chmod 600 "${_mc_tmp}" 2>/dev/null || true
    mv -f "${_mc_tmp}" "${MARKER}" 2>/dev/null || {
        rm -f "${_mc_tmp:?}"
        err "could not record completion in ${MARKER}; the next start would resolve again"
        return 1
    }
    log "resolution complete; recorded in ${MARKER}"
}

# -----------------------------------------------------------------------------------------
# Owned: the three internal users
#
# admin, kibanaserver and wazuh-manager ship with a ${NAME} placeholder for a hash. Each value is
# resolved, published in export/credentials.env for the manager and the dashboard, and written here
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
    file_contains "${_pip_account}:" "${INTERNAL_USERS}" start || return 0
    file_contains "\${${1}}" "${INTERNAL_USERS}"
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
    _hp_out=$(
        WAZUH_INDEXER_SECRET="$1" OPENSEARCH_JAVA_HOME="${DIR}/jdk" \
            "${SECURITY_TOOLS}/hash.sh" -env WAZUH_INDEXER_SECRET 2>/dev/null
    )
    # The last line with the bcrypt shape: $2a$NN$ and 53 characters of [./A-Za-z0-9].
    _hp_digest=""
    while IFS= read -r _hp_line || [ -n "${_hp_line}" ]; do
        case "${_hp_line}" in
            \$2[aby]\$[0-9][0-9]\$*)
                _hp_rest=${_hp_line#???????}
                case "${_hp_rest}" in *[!./A-Za-z0-9]*) continue ;; esac
                [ ${#_hp_rest} -eq 53 ] && _hp_digest=${_hp_line} ;;
        esac
    done <<EOT
${_hp_out}
EOT
    [ -n "${_hp_digest}" ] || return 1
    printf '%s' "${_hp_digest}"
}

# Replace one ${NAME} placeholder with its digest. Parameter expansion, not a pattern: neither the
# placeholder nor the digest -- which carries '$', '/' and '.' -- is ever interpreted.
#
# The result is written back through the original file rather than moved over it, so the ownership
# and mode the package set are preserved.
substitute_placeholder() {
    _sp_var="$1"
    _sp_file="$3"

    wazuh_check_file "${_sp_file}" || {
        err "refusing to write ${_sp_file}"
        return 1
    }

    _sp_tmp=$(mktemp "${_sp_file}.XXXXXX") || return 1

    _sp_placeholder="\${${_sp_var}}"
    _sp_digest="$2"
    while IFS= read -r _sp_line || [ -n "${_sp_line}" ]; do
        case "${_sp_line}" in
            *"${_sp_placeholder}"*)
                _sp_line="${_sp_line%%"${_sp_placeholder}"*}${_sp_digest}${_sp_line#*"${_sp_placeholder}"}"
                ;;
        esac
        printf '%s\n' "${_sp_line}"
    done < "${_sp_file}" > "${_sp_tmp}" || { rm -f "${_sp_tmp:?}"; return 1; }

    # cat, not mv: writing through the existing file keeps its inode, ownership
    # and mode. A mv would hand it mktemp's 0600 and this script's ownership.
    cat "${_sp_tmp}" > "${_sp_file}" || { rm -f "${_sp_tmp:?}"; return 1; }
    rm -f "${_sp_tmp:?}"
}

# The inverse of substitute_placeholder: put ${NAME} back where a digest was written, so the entry
# is once again the one the package shipped. Only --clear does this.
#
# It rewrites the whole hash line inside the account's block rather than searching for the digest,
# because by then the digest is the one thing we cannot name: it was derived from a password the
# published file no longer holds. Same guards as the forward direction -- a regular file only,
# written through the original inode so the ownership and mode the package set survive.
restore_placeholder() {
    _rp_account="$1"
    _rp_var="$2"
    _rp_file="$3"

    wazuh_check_file "${_rp_file}" || {
        err "refusing to write ${_rp_file}"
        return 1
    }

    # Already the shipped form: never resolved, or cleared before.
    file_contains "hash: \"\${${_rp_var}}\"" "${_rp_file}" && return 0

    _rp_tmp=$(mktemp "${_rp_file}.XXXXXX") || return 1

    _rp_seen=0
    _rp_restored=0
    _rp_inblock=0
    _rp_ws=" 	"
    while IFS= read -r _rp_line || [ -n "${_rp_line}" ]; do
        case "${_rp_line}" in
            "${_rp_account}:"*)
                _rp_inblock=1
                _rp_seen=1
                printf '%s\n' "${_rp_line}"
                continue
                ;;
            [!"${_rp_ws}"]*) _rp_inblock=0 ;;
        esac
        if [ "${_rp_inblock}" -eq 1 ]; then
            _rp_indent="${_rp_line%%[!"${_rp_ws}"]*}"
            case "${_rp_line#"${_rp_indent}"}" in
                hash:[" 	"]*)
                    printf '%shash: "${%s}"\n' "${_rp_indent}" "${_rp_var}"
                    _rp_restored=1
                    continue
                    ;;
            esac
        fi
        printf '%s\n' "${_rp_line}"
    done < "${_rp_file}" > "${_rp_tmp}"
    _rp_status=$?
    if [ "${_rp_status}" -eq 0 ]; then
        if [ "${_rp_seen}" -eq 0 ]; then
            _rp_status=3
        elif [ "${_rp_restored}" -eq 0 ]; then
            _rp_status=1
        fi
    fi

    # 3: no such account in this build. Nothing was ever resolved into it, so nothing to undo.
    if [ "${_rp_status}" -eq 3 ]; then
        rm -f "${_rp_tmp:?}"
        return 0
    fi
    if [ "${_rp_status}" -ne 0 ]; then
        rm -f "${_rp_tmp:?}"
        err "could not rewrite the ${_rp_account} entry of ${_rp_file}"
        return 1
    fi

    cat "${_rp_tmp}" > "${_rp_file}" || { rm -f "${_rp_tmp:?}"; return 1; }
    rm -f "${_rp_tmp:?}"
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
    file_contains "\${${_wuh_key}}" "${INTERNAL_USERS}" || return 0

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
            # that digest still works for whoever set it.
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
        # WAZUH_INDEXER_MANAGER_PASSWORD from export/credentials.env and the dashboard reads
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

# The node's name: the kernel's host name, without a domain.
host_name() {
    _hn=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n 2>/dev/null)
    printf '%s' "${_hn%%.*}"
}

# The names the operator wants on the node certificate: WAZUH_INDEXER_CERT_SANS from the process
# environment, then from local.env. Prints the list and returns 0; 1 when nothing supplies it; 2
# when what supplies it is empty or unusable, which is refused rather than silently discovered.
cert_sans_setting() {
    if [ "${WAZUH_INDEXER_CERT_SANS+x}" = x ]; then
        [ -n "${WAZUH_INDEXER_CERT_SANS}" ] || return 2
        printf '%s' "${WAZUH_INDEXER_CERT_SANS}"
        return 0
    fi
    _css_status=0
    _css_value=$(wazuh_local_get WAZUH_INDEXER_CERT_SANS) || _css_status=$?
    case "${_css_status}" in
        0)
            [ -n "${_css_value}" ] || return 2
            printf '%s' "${_css_value}"
            return 0
            ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

# Who this node claims to be. An explicit list ($1) replaces the derived one wholesale rather than
# extending it, so an operator who sets it gets exactly what they asked for. Loopback is always
# appended regardless, because indexer-security-init.sh and wazuh-passwords-tool.sh connect to
# localhost.
derive_sans() {
    if [ -n "${1-}" ]; then
        _ds_sans="$1"
    else
        _ds_sans=""
        # The node's name, and the name the resolver gives it when it has one (what `hostname -f`
        # looks up).
        _ds_node=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n 2>/dev/null)
        _ds_short="${_ds_node%%.*}"
        _ds_fqdn=""
        if [ -n "${_ds_node}" ] && _ds_hosts=$(getent hosts "${_ds_node}" 2>/dev/null); then
            set -- ${_ds_hosts}
            _ds_fqdn="${2-}"
        fi

        [ -n "${_ds_short}" ] && _ds_sans="DNS:${_ds_short}"
        if [ -n "${_ds_fqdn}" ] && [ "${_ds_fqdn}" != "${_ds_short}" ]; then
            _ds_sans="${_ds_sans:+${_ds_sans},}DNS:${_ds_fqdn}"
        fi

        # Global addresses on default-route interfaces only. Without that filter a host running
        # containers advertises docker0, veth* and CNI addresses too. The filter is a heuristic;
        # WAZUH_INDEXER_CERT_SANS is the escape hatch for when it guesses wrong.
        _ds_ifaces=""
        _ds_routes=$(ip -o route show default 2>/dev/null)
        while IFS= read -r _ds_line || [ -n "${_ds_line}" ]; do
            set -- ${_ds_line}
            while [ $# -gt 1 ]; do
                if [ "$1" = dev ]; then
                    case " ${_ds_ifaces} " in
                        *" $2 "*) ;;
                        *) _ds_ifaces="${_ds_ifaces} $2" ;;
                    esac
                    break
                fi
                shift
            done
        done <<EOT
${_ds_routes}
EOT
        for _ds_iface in ${_ds_ifaces}; do
            _ds_addrs=$(ip -o addr show dev "${_ds_iface}" scope global 2>/dev/null)
            while IFS= read -r _ds_line || [ -n "${_ds_line}" ]; do
                set -- ${_ds_line}
                _ds_addr="${4-}"
                _ds_addr="${_ds_addr%%/*}"
                [ -n "${_ds_addr}" ] && _ds_sans="${_ds_sans:+${_ds_sans},}IP:${_ds_addr}"
            done <<EOT
${_ds_addrs}
EOT
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

# A random, positive serial number, so no serial file is kept beside the CA.
random_serial() {
    _rs=$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
    [ -n "${_rs}" ] || return 1
    printf '0x%s' "${_rs}"
}

# issue_certificate <name> <subject> <sans> <ca dir> <group> <mode>: a key and a certificate issued
# from the CA, installed as root:<group> <mode>. The certificate file carries the leaf followed by
# the CA, so a client that trusts the CA can chain to it.
issue_certificate() {
    _ic_name="$1"
    _ic_subject="$2"
    _ic_sans="$3"
    _ic_ca="$4"
    _ic_group="$5"
    _ic_mode="$6"

    _ic_work=$(mktemp -d "${TMPDIR:-/tmp}/wazuh-indexer-certs.XXXXXX") || return 1
    chmod 700 "${_ic_work}"

    (
        umask 077
        openssl genrsa -out "${_ic_work}/key-temp.pem" 2048 2>/dev/null &&
        openssl pkcs8 -inform PEM -outform PEM -in "${_ic_work}/key-temp.pem" \
            -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "${_ic_work}/${_ic_name}-key.pem" 2>/dev/null
    ) || { rm -rf -- "${_ic_work:?}"; return 1; }

    openssl req -new -key "${_ic_work}/${_ic_name}-key.pem" -subj "${_ic_subject}" \
        -out "${_ic_work}/req.csr" 2>/dev/null || { rm -rf -- "${_ic_work:?}"; return 1; }

    printf 'subjectAltName = %s\n' "${_ic_sans}" > "${_ic_work}/req.ext"

    _ic_serial=$(random_serial) || { rm -rf -- "${_ic_work:?}"; return 1; }
    openssl x509 -req -in "${_ic_work}/req.csr" \
        -CA "${_ic_ca}/root-ca.pem" -CAkey "${_ic_ca}/root-ca.key" -set_serial "${_ic_serial}" \
        -sha256 -out "${_ic_work}/${_ic_name}.pem" -days 3650 \
        -extfile "${_ic_work}/req.ext" 2>/dev/null || { rm -rf -- "${_ic_work:?}"; return 1; }
    cat "${_ic_ca}/root-ca.pem" >> "${_ic_work}/${_ic_name}.pem" || { rm -rf -- "${_ic_work:?}"; return 1; }

    install -m "${_ic_mode}" -o root -g "${_ic_group}" "${_ic_work}/${_ic_name}-key.pem" "${CERTS_DIR}/${_ic_name}-key.pem" &&
    install -m "${_ic_mode}" -o root -g "${_ic_group}" "${_ic_work}/${_ic_name}.pem" "${CERTS_DIR}/${_ic_name}.pem"
    _ic_status=$?

    rm -rf -- "${_ic_work:?}"
    return ${_ic_status}
}

# The certificate's subject in the form the security plugin compares against.
subject_of() {
    [ -f "$1" ] || return 0
    _so_subject=$(openssl x509 -in "$1" -noout -subject -nameopt RFC2253 2>/dev/null) || return 0
    _so_subject="${_so_subject#subject=}"
    _so_subject="${_so_subject#"${_so_subject%%[! ]*}"}"
    printf '%s\n' "${_so_subject}"
}

# A YAML list item, commented out or not: optional blanks, an optional '#', optional blanks, then
# '-' followed by a blank.
dn_line_is_item() {
    _dli_rest="${1#"${1%%[! 	]*}"}"
    case "${_dli_rest}" in
        \#*) _dli_rest="${_dli_rest#\#}"; _dli_rest="${_dli_rest#"${_dli_rest%%[! 	]*}"}" ;;
    esac
    case "${_dli_rest}" in
        -[" 	"]*) return 0 ;;
    esac
    return 1
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
    wazuh_check_file "${CONFIG_FILE}" || {
        err "refusing to write ${CONFIG_FILE}"
        return 1
    }

    _sdn_tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1

    _sdn_skip=0
    while IFS= read -r _sdn_line || [ -n "${_sdn_line}" ]; do
        _sdn_key=""
        case "${_sdn_line}" in
            plugins.security.nodes_dn*)
                _sdn_rest="${_sdn_line#plugins.security.nodes_dn}"
                case "${_sdn_rest#"${_sdn_rest%%[! 	]*}"}" in :*) _sdn_key="node" ;; esac
                ;;
            plugins.security.authcz.admin_dn*)
                _sdn_rest="${_sdn_line#plugins.security.authcz.admin_dn}"
                case "${_sdn_rest#"${_sdn_rest%%[! 	]*}"}" in :*) _sdn_key="admin" ;; esac
                ;;
        esac
        if [ -n "${_sdn_key}" ]; then
            if [ "${_sdn_key}" = node ]; then
                _sdn_action="${_sdn_node_action}"; _sdn_name="plugins.security.nodes_dn"; _sdn_value="${_sdn_node}"
            else
                _sdn_action="${_sdn_admin_action}"; _sdn_name="plugins.security.authcz.admin_dn"; _sdn_value="${_sdn_admin}"
            fi
            if [ "${_sdn_action}" = keep ]; then
                _sdn_skip=0
                printf '%s\n' "${_sdn_line}"
                continue
            fi
            printf '%s:\n' "${_sdn_name}"
            [ "${_sdn_action}" = set ] && printf -- '- "%s"\n' "${_sdn_value}"
            _sdn_skip=1
            continue
        fi
        if [ "${_sdn_skip}" -eq 1 ] && dn_line_is_item "${_sdn_line}"; then
            continue
        fi
        _sdn_skip=0
        printf '%s\n' "${_sdn_line}"
    done < "${CONFIG_FILE}" > "${_sdn_tmp}" || { rm -f "${_sdn_tmp:?}"; return 1; }

    # Written back through the original file rather than moved over it, so the mode and ownership
    # the package set survive.
    cat "${_sdn_tmp}" > "${CONFIG_FILE}" || { rm -f "${_sdn_tmp:?}"; return 1; }
    rm -f "${_sdn_tmp:?}"
}

# True when the setting carries no value: nothing after the colon and no list item under it.
# A key that is not in the file at all is not empty -- there is nothing to fill.
dn_is_empty() {
    _die_state=""
    while IFS= read -r _die_line || [ -n "${_die_line}" ]; do
        if [ -n "${_die_state}" ]; then
            # The line after an empty key decides: a list item fills it.
            dn_line_is_item "${_die_line}" && _die_state=filled
            break
        fi
        case "${_die_line}" in
            "$1:"*)
                _die_rest=$(printf '%s' "${_die_line#"$1:"}" | tr -d '[:space:]')
                if [ -z "${_die_rest}" ]; then
                    _die_state=empty
                else
                    _die_state=filled
                    break
                fi
                ;;
        esac
    done < "${CONFIG_FILE}"
    [ "${_die_state}" = empty ]
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
# passed as -untrusted, so a certificate that carries its intermediate CAs verifies too, and
# -partial_chain lets the anchor be an issuing CA rather than a self-signed root, which the node's
# trust store accepts as well. Expiry is not this check's business.
pair_issued_by() {
    for _pi in indexer admin; do
        [ -f "${CERTS_DIR}/${_pi}.pem" ] || continue
        openssl verify -no_check_time -partial_chain -CAfile "$1" \
            -untrusted "${CERTS_DIR}/${_pi}.pem" "${CERTS_DIR}/${_pi}.pem" > /dev/null 2>&1 || return 1
    done
    return 0
}

# certs/ is root's, entered and read by the service group. A certificate pair staged there by the
# operator is checked, never repaired: the pre-start check names what is wrong with it.
ensure_certs_dir() {
    if [ ! -e "${CERTS_DIR}" ] && [ ! -L "${CERTS_DIR}" ]; then
        mkdir -m 0750 "${CERTS_DIR}" || return 1
        chown "root:${SERVICE_GROUP}" "${CERTS_DIR}" || return 1
        if command -v restorecon > /dev/null 2>&1; then
            restorecon "${CERTS_DIR}" > /dev/null 2>&1 || true
        fi
    fi
    wazuh_check_dir "${CERTS_DIR}" || return 1
}

# The anchor the node trusts, as a copy the service group can read.
install_anchor() {
    install -m 0640 -o root -g "${SERVICE_GROUP}" "$1" "${CERTS_DIR}/root-ca.pem"
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

    ensure_certs_dir || {
        err "${CERTS_DIR} could not be prepared"
        return 1
    }

    # C: an operator staged an issued pair, or a purge kept one. A pair the anchor did not issue
    # would leave the node unable to complete a handshake while the resolution reports success, so
    # it is checked first. The anchor is the CA directory's; with nothing there, the copy staged
    # beside the pair, and no CA is minted: a new one could not have issued it.
    if [ -f "${CERTS_DIR}/indexer.pem" ] && [ -f "${CERTS_DIR}/indexer-key.pem" ]; then
        for _rc_staged in indexer.pem indexer-key.pem admin.pem admin-key.pem root-ca.pem; do
            wazuh_check_file "${CERTS_DIR}/${_rc_staged}"
            case $? in
                2)
                    err "        the pair staged in ${CERTS_DIR} must be root's: chown root:${SERVICE_GROUP}, chmod 0640"
                    return 1
                    ;;
            esac
        done

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
            err "        stage the root-ca.pem that issued it beside the pair, in ${CERTS_DIR},"
            err "        or in ${_rc_ca} (directory root:${SERVICE_GROUP} 0750, file root:${SERVICE_GROUP} 0640)"
            return 1
        fi
        if ! pair_issued_by "${_rc_anchor}"; then
            err "the certificate pair in ${CERTS_DIR} was not issued by ${_rc_anchor}"
            err "        stage the CA that issued it, or remove the pair so that this node issues a new one"
            return 1
        fi

        if [ "${_rc_anchor}" != "${CERTS_DIR}/root-ca.pem" ]; then
            install_anchor "${_rc_anchor}" || return 1
        else
            # The anchor staged beside the pair is the CA this node trusts, so it is what the
            # manager and the dashboard on this host must trust too.
            wazuh_ca_publish_file "${_rc_anchor}" || {
                err "could not publish ${_rc_anchor} in ${EXPORT_DIR}"
                return 1
            }
        fi

        log "found an issued certificate pair in ${CERTS_DIR}; generating nothing"
        write_distinguished_names
        return 0
    fi

    if ! wazuh_ca_ensure; then
        err "the CA directory could not be prepared"
        return 1
    fi

    if [ -f "${_rc_ca}/root-ca.pem" ]; then
        install_anchor "${_rc_ca}/root-ca.pem" || return 1
    fi

    # D: a trust anchor but no way to sign and no pair.
    if [ ! -f "${_rc_ca}/root-ca.key" ]; then
        err "${_rc_ca}/root-ca.pem carries no signing key and no issued pair is staged in ${CERTS_DIR}"
        return 1
    fi

    _rc_sans_status=0
    _rc_given=$(cert_sans_setting) || _rc_sans_status=$?
    if [ "${_rc_sans_status}" -eq 2 ]; then
        err "WAZUH_INDEXER_CERT_SANS is set but empty or unusable; name at least one address, or unset it"
        return 1
    fi

    _rc_short=$(host_name)
    [ -n "${_rc_short}" ] || _rc_short="wazuh-indexer"
    _rc_sans=$(derive_sans "${_rc_given}")
    # wazuh-certs-tool issues with this same RDN order, so a deployment that later replaces these
    # with the tool's own certificates keeps the DNs already written into opensearch.yml valid.
    _rc_suffix="/OU=Wazuh/O=Wazuh/L=California/C=US"

    # The node's pair is read by the service through its group. The admin pair is root's alone:
    # indexer-security-init.sh runs securityadmin as root, and the service account must not be
    # able to act as the security administrator.
    issue_certificate "indexer" "/CN=${_rc_short}${_rc_suffix}" "${_rc_sans}" "${_rc_ca}" "${SERVICE_GROUP}" 0640 || {
        err "could not issue the node certificate"
        return 1
    }
    issue_certificate "admin" "/CN=admin${_rc_suffix}" "DNS:localhost" "${_rc_ca}" root 0600 || {
        err "could not issue the admin certificate"
        return 1
    }

    # A wrong name fails only at the first peer connection, not here, so log what this node
    # presents.
    log "issued indexer.pem: CN=${_rc_short}; SANs ${_rc_sans}"

    write_distinguished_names
    return 0
}

# -----------------------------------------------------------------------------------------
# The keystore
#
# The node creates opensearch.keystore at its first start when it is absent, and the
# configuration directory is root's now, so this step, as root, does it instead, at every run
# where it is still missing. It comes after the certificates: the keystore tool loads
# opensearch.yml, and refuses it while the DN settings the resolution fills are still empty.
# Nothing is written through an existing entry: a link or anything else in its place is reported
# by the file checks.
# -----------------------------------------------------------------------------------------

ensure_keystore() {
    _ek_file="${CONFIG_DIR}/opensearch.keystore"
    [ -e "${_ek_file}" ] || [ -L "${_ek_file}" ] && return 0
    [ -x "${DIR}/bin/opensearch-keystore" ] || return 0
    if OPENSEARCH_PATH_CONF="${CONFIG_DIR}" "${DIR}/bin/opensearch-keystore" create < /dev/null > /dev/null; then
        chown "root:${SERVICE_GROUP}" "${_ek_file}" 2>/dev/null || true
        chmod 0640 "${_ek_file}" 2>/dev/null || true
        # The digest of the keystore as created, so that a purge can tell it from one the
        # operator put secrets in.
        sha256sum < "${_ek_file}" | _wazuh_write_file "${CONFIG_DIR}/.wazuh-indexer-keystore" 0600 || true
        log "created ${_ek_file}"
    else
        err "could not create ${_ek_file}; the node will not start without it"
    fi
}

# -----------------------------------------------------------------------------------------
# --clear
#
# The one destructive path, for an image built by installing the package. Two things it does not
# remove: a CA this package did not mint, and the operator's local.env.
# -----------------------------------------------------------------------------------------

# The pidfile plus kill -0, using only builtins. pgrep would have been shorter but it lives in
# procps-ng, which a minimal image need not carry -- and a guard that silently answers "not
# running" because its binary is absent is worse than no guard at all on the one path in this
# script that destroys credentials. The pid directory is the service account's, so a link in it
# is not a pidfile.
indexer_is_running() {
    for _iir_pid in "${PID_DIR}"/*.pid; do
        [ -f "${_iir_pid}" ] && [ ! -L "${_iir_pid}" ] || continue
        IFS= read -r _iir_n < "${_iir_pid}" 2>/dev/null || continue
        case "${_iir_n}" in ''|*[!0-9]*) continue ;; esac
        # A stale pidfile from an unclean stop is not a running node.
        kill -0 "${_iir_n}" 2>/dev/null && return 0
    done
    return 1
}

# A digest in internal_users.yml and the password in export/credentials.env are one credential in
# two halves. Taking back only the published half is what leaves a node holding new passwords and
# the old digests: the next resolution generates, publishes, finds no placeholder to write into,
# and says nothing, because a missing placeholder is also how an account this build does not ship
# looks.
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

    if [ -e "${MARKER}" ] || [ -L "${MARKER}" ]; then
        rm -f -- "${MARKER:?}"
        log "removed the initialisation marker; the next start re-initialises the security configuration"
    fi

    for _cc_file in indexer.pem indexer-key.pem admin.pem admin-key.pem root-ca.pem; do
        if [ -e "${CERTS_DIR}/${_cc_file}" ] || [ -L "${CERTS_DIR}/${_cc_file}" ]; then
            rm -f -- "${CERTS_DIR:?}/${_cc_file:?}"
            log "removed certs/${_cc_file}"
        fi
    done

    # The CA goes only when this package minted it; a staged one is the operator's.
    _cc_ca=$(wazuh_ca_get_dir 2>/dev/null) || _cc_ca=""
    if [ -n "${_cc_ca}" ] && wazuh_ca_is_minted; then
        for _cc_ca_file in root-ca.pem root-ca.key root-ca.srl .wazuh-indexer-bootstrap-ca; do
            rm -f -- "${_cc_ca:?}/${_cc_ca_file:?}"
        done
        log "removed the bootstrap CA in ${_cc_ca}"
    elif [ -n "${_cc_ca}" ] && { [ -f "${_cc_ca}/root-ca.pem" ] || [ -f "${_cc_ca}/root-ca.key" ]; }; then
        log "keeping the CA in ${_cc_ca}: it was staged, not minted here"
    fi

    untrust_ca

    # The DNs are derived from certificates that are now gone. Left behind, they would be the only
    # thing an image built this way still carries from the build host -- and the rule above, which
    # fills empty keys only, would never replace them.
    if set_distinguished_names "clear" "" "clear" ""; then
        log "cleared the node and admin DNs in opensearch.yml"
    fi

    # Everything this package published.
    for _cc_key in ${OWNED_KEYS}; do
        wazuh_env_unset "${_cc_key}" >/dev/null 2>&1 || true
    done
    for _cc_published in credentials.env ca.pem; do
        if [ -e "${EXPORT_DIR}/${_cc_published}" ] || [ -L "${EXPORT_DIR}/${_cc_published}" ]; then
            rm -f -- "${EXPORT_DIR:?}/${_cc_published:?}"
        fi
    done
    log "removed what was published in ${EXPORT_DIR}"

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

# The file checks come first in every mode. --check stops here either way; --prestart stops here
# on a problem, so a tampered node does not start; the installer reports and carries on, because
# a maintainer script never fails, and every write below re-checks its own target anyway.
if check_files; then
    [ "${MODE}" = "check" ] && log "files checked: no problem found"
else
    if [ "${MODE}" = "check" ] || [ "${MODE}" = "prestart" ]; then
        err "the files above must be corrected before the service starts"
        exit 1
    fi
fi
if [ "${MODE}" = "check" ]; then
    exit 0
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
    ensure_keystore
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

# The keystore is not a credential this script resolves, so it is not subject to the marker; it
# needs the DN settings in place, which the certificate step wrote.
if [ "${CERTIFICATES_RESOLVED}" = "1" ]; then
    ensure_keystore
fi

# The installer has no opinion about whether the component can run: no warning, no failure, no
# special state. Nothing checks credentials until something needs them.
if [ "${MODE}" = "install" ] || [ "${MODE}" = "upgrade" ]; then
    exit 0
fi

if [ -z "${UNRESOLVED}" ] && [ -z "${INVALID}" ] && [ "${CERTIFICATES_RESOLVED}" = "1" ]; then
    exit 0
fi

# The message goes to the journal, which is where someone looks when a service will not start.
# It names every missing key and where to set it, and never prints a value.
for _key in ${INVALID}; do
    err "INVALID ${_key}: the supplied value does not meet the password policy"
    err "        12 to 64 characters from A-Z a-z 0-9 . , _ + : @ % ^ = ~ -"
    err "        with at least one uppercase letter, one lowercase letter, one digit and one symbol"
    err "        correct it in ${LOCAL_ENV} and start the service again"
done

for _key in ${UNRESOLVED}; do
    err "MISSING ${_key}"
    err "        set it in ${LOCAL_ENV} (root:root 0600)"
done

if [ "${CERTIFICATES_RESOLVED}" != "1" ]; then
    err "MISSING TLS certificates"
    err "        stage indexer.pem and indexer-key.pem in ${CERTS_DIR} (root:${SERVICE_GROUP} 0640)"
fi

exit 1
