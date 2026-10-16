#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Acceptance tests for install-time credential and TLS resolution.
# See https://github.com/wazuh/wazuh-indexer/issues/1927 and
# https://github.com/wazuh/wazuh-indexer/issues/2020
#
# Exercises the wazuh-indexer package end to end: that it generates its own
# passwords and certificates at install, under its own /etc/wazuh-indexer and
# nowhere else; that it publishes what the manager and the dashboard need in
# export/; that the configuration directory is root's and the service account
# can write nothing in it; that the node comes up; that the three internal
# users authenticate once an operator has uploaded the security configuration;
# that resolution never happens a second time; that planted material is refused
# before the service starts; and that removal and purge take back exactly what
# they own.
#
# This is deliberately a plain script with no framework, so it can be run
# anywhere the package can be installed: a CI container, a Vagrant box, a VM.
#
#   PACKAGE=/path/to/wazuh-indexer_5.0.0-0_amd64.deb bash test_credentials.sh
#
# Requirements: root, systemd as PID 1, and the package's own dependencies. It
# installs and then removes wazuh-indexer, so it needs a throwaway host.
#
#   KEEP_PACKAGE=1   leave the package installed at the end (for debugging)
#   SKIP_PURGE=1     stop after the removal phase
#
# Exit status is the number of failed checks, capped at 125, so a caller can
# branch on success without parsing the report.

set -u

PACKAGE="${PACKAGE:-}"
KEEP_PACKAGE="${KEEP_PACKAGE:-0}"
SKIP_PURGE="${SKIP_PURGE:-0}"

NAME="wazuh-indexer"
CONFIG_DIR="/etc/wazuh-indexer"
EXPORT_DIR="${CONFIG_DIR}/export"
CREDENTIALS="${EXPORT_DIR}/credentials.env"
CA_DIR="${CONFIG_DIR}/ca"
LOCAL_ENV="${CONFIG_DIR}/local.env"
CERTS_DIR="${CONFIG_DIR}/certs"
INTERNAL_USERS="${CONFIG_DIR}/opensearch-security/internal_users.yml"
OPENSEARCH_YML="${CONFIG_DIR}/opensearch.yml"
KEYSTORE="${CONFIG_DIR}/opensearch.keystore"
DATA_DIR="/var/lib/wazuh-indexer"
LOG_DIR="/var/log/wazuh-indexer"
MARKER="${DATA_DIR}/.initialized"
PRODUCT_DIR="/usr/share/wazuh-indexer"
SECURITY_TOOLS="${PRODUCT_DIR}/plugins/opensearch-security/tools"
WAZUH_TOOLS="${PRODUCT_DIR}/tools"
HELPER="${PRODUCT_DIR}/lib/wazuh-indexer-credentials.sh"
RESOLVER="${PRODUCT_DIR}/bin/resolve-credentials.sh"
API="https://127.0.0.1:9200"

PASSED=0
FAILED=0
SKIPPED=0
FAILURES=""

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

section() {
    printf '\n\033[1m== %s ==\033[0m\n' "$*"
}

ok() {
    PASSED=$((PASSED + 1))
    printf '  ok:   %s\n' "$*"
}

fail() {
    FAILED=$((FAILED + 1))
    FAILURES="${FAILURES}\n  - $*"
    printf '  FAIL: %s\n' "$*"
}

skip() {
    SKIPPED=$((SKIPPED + 1))
    printf '  skip: %s\n' "$*"
}

info() {
    printf '  info: %s\n' "$*"
}

# check <description> <command...>
check() {
    _desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "${_desc}"; else fail "${_desc}"; fi
}

check_eq() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        fail "$1 (expected '$2', got '$3')"
    fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Read a key from the published credentials file without sourcing it, and
# without relying on the package's helper being installed (removal tests run
# after it is gone).
cred_get() {
    [ -f "${CREDENTIALS}" ] || return 1
    _line=$(grep -E "^[[:space:]]*$1=" "${CREDENTIALS}" 2>/dev/null | tail -n 1)
    [ -n "${_line}" ] || return 1
    _value="${_line#*=}"
    case "${_value}" in
        \'*\') _value="${_value#\'}"; _value="${_value%\'}" ;;
        \"*\") _value="${_value#\"}"; _value="${_value%\"}" ;;
    esac
    printf '%s' "${_value}"
}

cred_count() {
    _c=$(grep -cE '^[[:space:]]*WAZUH_INDEXER_[A-Z_]+=' "${CREDENTIALS}" 2>/dev/null | head -1)
    printf '%s' "${_c:-0}"
}

api_status() {
    curl -sk -o /dev/null -w '%{http_code}' -u "$1:$2" "${API}/_cluster/health" 2>/dev/null
}

# A listening socket is not a ready cluster: the security plugin answers 503
# while the cluster state is still forming, so waiting only for "any HTTP code"
# produces spurious failures on the checks that follow a restart.
wait_for_node() {
    _n=0
    while [ "${_n}" -lt 60 ]; do
        if [ "$(curl -sk -o /dev/null -w '%{http_code}' "${API}/" 2>/dev/null)" != "000" ]; then
            return 0
        fi
        _n=$((_n + 1))
        sleep 2
    done
    return 1
}

# Wait until the node answers something other than 503 for an authenticated
# request, i.e. the cluster is actually serving.
wait_for_cluster() {
    _n=0
    while [ "${_n}" -lt 60 ]; do
        _code=$(api_status "$1" "$2")
        case "${_code}" in
            000|503) ;;
            *) return 0 ;;
        esac
        _n=$((_n + 1))
        sleep 2
    done
    return 1
}

# OpenSearch refuses to start below 262144 and the node dies in bootstrap
# checks. The package ships a sysctl.d drop-in and postinst restarts
# systemd-sysctl, but that does not reliably take effect inside a container, and
# CI runners default to 65530. This is a global kernel setting, not a namespaced
# one, so in a privileged container the write lands on the host -- which is what
# makes it work here and why it is raised rather than lowered.
ensure_max_map_count() {
    _want=262144
    _have=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)
    if [ "${_have}" -ge "${_want}" ]; then
        info "vm.max_map_count=${_have}"
        return 0
    fi
    if sysctl -w vm.max_map_count="${_want}" >/dev/null 2>&1; then
        info "raised vm.max_map_count from ${_have} to ${_want}"
        return 0
    fi
    echo "FATAL: vm.max_map_count is ${_have} and could not be raised to ${_want}." >&2
    echo "       The node will fail its bootstrap checks. Run the container with" >&2
    echo "       --privileged, or set the value on the host before starting." >&2
    exit 125
}

# What internal_users.yml currently holds for one account: a bcrypt digest once
# it is resolved, the ${NAME} placeholder before that and after --clear.
hash_of() {
    awk -v u="$1" '
        substr($0, 1, length(u) + 1) == u ":" { f = 1; next }
        /^[^[:space:]]/ { f = 0 }
        f && /hash:/ {
            sub(/^[[:space:]]*hash:[[:space:]]*"?/, "")
            sub(/"$/, "")
            print
            exit
        }
    ' "${INTERNAL_USERS}"
}

have_bcrypt() { command -v python3 >/dev/null 2>&1 && python3 -c 'import bcrypt' 2>/dev/null; }

# digest_verifies <digest> <password>. $2y$ is bcrypt's PHP variant tag; the
# algorithm is the one python-bcrypt calls $2b$, and it refuses the tag it does
# not know rather than the hash.
digest_verifies() {
    HS="$1" PW="$2" python3 -c 'import bcrypt,os,sys; sys.exit(0 if bcrypt.checkpw(os.environ["PW"].encode(), os.environ["HS"].replace("$2y$","$2b$").encode()) else 1)' 2>/dev/null
}

# A certificate's subject as the security plugin compares it, and the list a DN setting holds.
subject_of() {
    openssl x509 -in "$1" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//'
}

dn_list() {
    awk -v k="$1" '
        index($0, k ":") == 1 { f = 1; next }
        f && /^[[:space:]]*-/ { gsub(/^[[:space:]]*-[[:space:]]*"?|"$/, ""); print; next }
        f { exit }
    ' "${OPENSEARCH_YML}"
}

# The bundled JDK has to trust the Wazuh CA, and --clear has to take that back.
TRUSTSTORE="${PRODUCT_DIR}/jdk/lib/security/cacerts"

ca_is_trusted() {
    LC_ALL=C "${PRODUCT_DIR}/jdk/bin/keytool" -list -keystore "${TRUSTSTORE}" \
        -storepass changeit -alias wazuh-root-ca > /dev/null 2>&1 && echo yes || echo no
}

# The account/key pairs this package owns, as "<account>:<KEY>".
OWNED_PAIRS="admin:WAZUH_INDEXER_ADMIN_PASSWORD kibanaserver:WAZUH_INDEXER_KIBANASERVER_PASSWORD wazuh-manager:WAZUH_INDEXER_MANAGER_PASSWORD"

mode_of() { stat -c '%a' "$1" 2>/dev/null; }
owner_of() { stat -c '%U:%G' "$1" 2>/dev/null; }
# The host's short name, without hostname(1): the package no longer depends on it.
short_hostname() { local h; h=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n); printf '%s' "${h%%.*}"; }
is() { [ "$(mode_of "$2")" = "$1" ] && [ "$(owner_of "$2")" = "$3" ]; }
same() { [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]; }
fingerprint() { sha256sum "$@" 2>/dev/null | sha256sum | cut -c1-16; }

# Run a command as the service account, with coreutils alone: the package no
# longer depends on util-linux, so runuser may be absent from the host.
as_service() {
    chroot --userspec="${NAME}:${NAME}" --skip-chdir / /bin/sh -c "$*"
}

# True when a node (the OpenSearch bootstrap class) is running, read from /proc:
# the package no longer depends on procps, so pgrep may be absent from the host.
node_running() {
    for _nr in /proc/[0-9]*/cmdline; do
        tr '\0' ' ' < "${_nr}" 2>/dev/null | grep -q 'org.opensearch.bootstrap.OpenSearch' && return 0
    done
    return 1
}

# Journal lines the service emitted at ERROR level or above, excluding the ones
# a correct installation legitimately produces.
service_errors() {
    journalctl -u wazuh-indexer --no-pager 2>/dev/null \
        | grep -iE '\b(error|fatal|exception)\b' \
        | grep -viE 'ErrorFile|OnOutOfMemoryError|HeapDumpOnOutOfMemoryError|error_trace|no-error' \
        || true
}

# The security plugin walks the whole configuration directory at start and warns
# about every file readable by others and every directory others can enter.
permission_warnings() {
    { journalctl -u wazuh-indexer --no-pager 2>/dev/null; cat "${LOG_DIR}"/*.log 2>/dev/null; } \
        | grep -F 'insecure file permissions' || true
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

section "Preconditions"

if [ "$(id -u)" != "0" ]; then
    echo "FATAL: must run as root" >&2
    exit 125
fi

if [ -z "${PACKAGE}" ] || [ ! -f "${PACKAGE}" ]; then
    echo "FATAL: set PACKAGE to the .deb or .rpm to test" >&2
    exit 125
fi
info "package: ${PACKAGE}"

case "${PACKAGE}" in
    *.deb) PKG_KIND="deb" ;;
    *.rpm) PKG_KIND="rpm" ;;
    *) echo "FATAL: unrecognised package type: ${PACKAGE}" >&2; exit 125 ;;
esac
info "type:    ${PKG_KIND}"

if ! pidof systemd >/dev/null 2>&1 && [ ! -d /run/systemd/system ]; then
    echo "FATAL: systemd is not running; the unit cannot be exercised" >&2
    exit 125
fi

for tool in curl openssl grep awk stat; do
    command -v "${tool}" >/dev/null 2>&1 || { echo "FATAL: missing ${tool}" >&2; exit 125; }
done

# A previous run must not colour the results.
if [ -e "${EXPORT_DIR}" ] || [ -e "${MARKER}" ] || [ -e /etc/wazuh ]; then
    echo "FATAL: ${EXPORT_DIR}, ${MARKER} or /etc/wazuh already exists; use a clean host" >&2
    exit 125
fi
ensure_max_map_count
ok "clean host, package present, systemd running"

# ---------------------------------------------------------------------------
# 1. Installation
# ---------------------------------------------------------------------------

section "1. Installing wazuh-indexer"

# `dpkg -i` on purpose: that is how the maintainer scripts are exercised the way
# an operator's own `dpkg -i` would exercise them, and routing the install
# through apt would hide unpack-time behaviour behind dependency resolution.
#
# dpkg resolves nothing, so the declared dependencies go on the host first --
# read out of the package by the helper beside this script, never hard-coded, so
# they cannot drift when Depends changes. yum localinstall resolves its own.
if [ "${PKG_KIND}" = "deb" ]; then
    HERE="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${HERE}/install_package_dependencies.sh" ]; then
        bash "${HERE}/install_package_dependencies.sh" "${PACKAGE}" >/tmp/deps.log 2>&1 \
            || { fail "could not install the declared dependencies"; tail -5 /tmp/deps.log | sed 's/^/        /'; }
    else
        skip "dependency pre-install (install_package_dependencies.sh not beside this script)"
    fi
    DEBIAN_FRONTEND=noninteractive dpkg -i "${PACKAGE}" >/tmp/install.log 2>&1
else
    yum localinstall -y "${PACKAGE}" >/tmp/install.log 2>&1
fi
INSTALL_RC=$?
check_eq "package installs cleanly" "0" "${INSTALL_RC}"
if [ "${INSTALL_RC}" != "0" ]; then
    info "installer output:"
    sed 's/^/        /' /tmp/install.log | tail -20
fi

# 1.a The installer must never leak a secret into its own output.
if grep -qiE '(password|hash)[^=]*=[^ ]{12,}' /tmp/install.log 2>/dev/null; then
    fail "installer output contains something that looks like a secret"
    info "$(grep -iE '(password|hash)[^=]*=' /tmp/install.log | head -3)"
else
    ok "installer printed no secret"
fi

# 1.b The install has to end by saying where the passwords are and how to continue. A first-time
# user has no other way to find either, and the per-key progress lines it used to end with told
# them nothing they could act on.
check "the install says where the passwords are" \
    grep -qF "${CREDENTIALS}" /tmp/install.log
check "the install names the dashboard login" \
    grep -qF "as admin, with WAZUH_INDEXER_ADMIN_PASSWORD" /tmp/install.log
check "the install says the service is neither running nor enabled" \
    grep -qF "not running, and will not start at boot" /tmp/install.log
check "the install gives the command that starts and enables it" \
    grep -qE "enable --now|chkconfig --add" /tmp/install.log
# The package ran daemon-reload itself before printing this, so asking for it again would be noise.
check "the install does not ask for a redundant daemon-reload" \
    bash -c "! grep -q 'sudo systemctl daemon-reload' /tmp/install.log"
check "the install points at indexer-security-init.sh" \
    grep -qF "indexer-security-init.sh" /tmp/install.log
check "the install says it opens no firewall port" \
    grep -qF "opens no firewall port" /tmp/install.log
check "the per-key progress lines are not in the install output" \
    bash -c "! grep -q 'published WAZUH_INDEXER' /tmp/install.log"

# 1.a2 Everything the resolver needs must be on the host, and nothing else may
# be declared: the dependency list is exactly the host tools the scripts run.
for tool in openssl ip getent; do
    if command -v "${tool}" >/dev/null 2>&1; then
        ok "dependency provides ${tool}"
    else
        fail "${tool} is absent: a declared dependency did not resolve"
    fi
done
if [ "${PKG_KIND}" = "deb" ]; then
    declared=$(dpkg-deb -f "${PACKAGE}" Depends 2>/dev/null | tr ',' '\n' | sed -e 's/(.*)//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort | tr '\n' ' ')
    check_eq "the DEB declares exactly iproute2, openssl and passwd" "iproute2 openssl passwd " "${declared}"
else
    declared=$(rpm -qp --requires "${PACKAGE}" 2>/dev/null | grep -vE '^rpmlib\(' | sort -u | tr '\n' ' ')
    for want in /bin/sh openssl iproute /usr/sbin/groupadd /usr/sbin/useradd /usr/sbin/userdel /usr/sbin/groupdel; do
        case " ${declared} " in
            *" ${want} "*) ok "the RPM requires ${want}" ;;
            *) fail "the RPM does not require ${want}" ;;
        esac
    done
    for gone in coreutils diffutils hostname procps-ng util-linux; do
        case " ${declared} " in
            *" ${gone} "*) fail "the RPM still requires ${gone}" ;;
            *) ok "the RPM no longer requires ${gone}" ;;
        esac
    done
fi

# 1.b The installer must not start or enable the service.
# `systemctl is-active` prints AND exits non-zero, so `|| echo` would append a
# second line rather than substitute one.
check_eq "service not started by the installer" "inactive" \
    "$(systemctl is-active wazuh-indexer 2>/dev/null | head -1)"
check_eq "service not enabled by the installer" "disabled" \
    "$(systemctl is-enabled wazuh-indexer 2>/dev/null | head -1)"

section "1.0 Ownership: the service account cannot rewrite what root runs"

# Root executes bin/resolve-credentials.sh and sources lib/wazuh-indexer-credentials.sh.
# If the service account owned either, it could have root run its own code.
for f in "${RESOLVER}" "${HELPER}"; do
    check_eq "$(basename "${f}") is root-owned" "root:wazuh-indexer" "$(owner_of "${f}")"
    mode="$(mode_of "${f}")"
    case "${mode}" in
        ?[0-7][0-7]) group_digit=$(printf '%s' "${mode}" | cut -c2) ;;
        *) group_digit="" ;;
    esac
    case "${group_digit}" in
        2|3|6|7) fail "$(basename "${f}") is group-writable (mode ${mode})" ;;
        "")      fail "$(basename "${f}") has an unreadable mode (${mode})" ;;
        *)       ok "$(basename "${f}") is not group-writable (mode ${mode})" ;;
    esac
done
check "the shared helper of the previous model is not shipped" \
    bash -c "[ ! -e '${PRODUCT_DIR}/lib/wazuh-credentials.sh' ]"
check "no package test suite is shipped under the product tree" \
    bash -c "! ls -d '${PRODUCT_DIR}'/test* 2>/dev/null | grep -q ."

# systemd reads the EnvironmentFile as root; a service-writable copy would let
# the service account set variables for the root pre-start step.
for envfile in /etc/default/wazuh-indexer /etc/sysconfig/wazuh-indexer; do
    [ -f "${envfile}" ] || continue
    check_eq "${envfile} is root-owned" "root" "$(stat -c '%U' "${envfile}" 2>/dev/null)"
    check_eq "${envfile} is 0640" "640" "$(mode_of "${envfile}")"
done

# Carve-outs: the service genuinely writes these, and the ownership change must
# not have taken them away.
for writable in "${PRODUCT_DIR}/engine" \
                "${PRODUCT_DIR}/plugins/wazuh-indexer-content-manager/snapshots"; do
    if [ ! -d "${writable}" ]; then
        skip "$(basename "${writable}") not present in this build"
        continue
    fi
    if as_service "test -w '${writable}'" 2>/dev/null; then
        ok "$(basename "${writable}") is still writable by the service account"
    else
        fail "$(basename "${writable}") is no longer writable by the service account"
    fi
done

# The service-owned trees: data and logs. A root-owned DATA_DIR stops the node
# creating nodes/ and it dies in NodeEnvironment before anything else runs.
for owned in "${DATA_DIR}" "${LOG_DIR}"; do
    [ -d "${owned}" ] || continue
    if as_service "test -w '${owned}'" 2>/dev/null; then
        ok "${owned} is writable by the service account"
    else
        fail "${owned} is not writable by the service account (the node will not start)"
    fi
done

section "1.0b Layout: the configuration directory is root's"

check "${CONFIG_DIR} is root:wazuh-indexer 0750" is 750 "${CONFIG_DIR}" root:wazuh-indexer
for f in opensearch.yml jvm.options log4j2.properties; do
    check "${f} is root:wazuh-indexer 0640" is 640 "${CONFIG_DIR}/${f}" root:wazuh-indexer
done
check "opensearch-security/ is root:wazuh-indexer 0750" is 750 "${CONFIG_DIR}/opensearch-security" root:wazuh-indexer
check "internal_users.yml is root:wazuh-indexer 0640" is 640 "${INTERNAL_USERS}" root:wazuh-indexer
check "the keystore was created by the package" test -f "${KEYSTORE}"
check "the keystore is root:wazuh-indexer 0640" is 640 "${KEYSTORE}" root:wazuh-indexer
check "export/ is root:wazuh-indexer 0750" is 750 "${EXPORT_DIR}" root:wazuh-indexer
check "export/credentials.env is root:root 0600" is 600 "${CREDENTIALS}" root:root
check "export/ca.pem is root:wazuh-indexer 0640" is 640 "${EXPORT_DIR}/ca.pem" root:wazuh-indexer
check "ca/ is root:wazuh-indexer 0750" is 750 "${CA_DIR}" root:wazuh-indexer
check "ca/root-ca.pem is root:wazuh-indexer 0640" is 640 "${CA_DIR}/root-ca.pem" root:wazuh-indexer
check "ca/root-ca.key is root:root 0400" is 400 "${CA_DIR}/root-ca.key" root:root
check "the bootstrap marker records that the package minted the CA" is 600 "${CA_DIR}/.wazuh-indexer-bootstrap-ca" root:root
check "certs/ is root:wazuh-indexer 0750" is 750 "${CERTS_DIR}" root:wazuh-indexer
for f in indexer.pem indexer-key.pem root-ca.pem; do
    check "certs/${f} is root:wazuh-indexer 0640" is 640 "${CERTS_DIR}/${f}" root:wazuh-indexer
done
for f in admin.pem admin-key.pem; do
    check "certs/${f} is root:root 0600 (securityadmin runs as root)" is 600 "${CERTS_DIR}/${f}" root:root
done
check "no file under ${CONFIG_DIR} is readable by others" \
    bash -c "! find '${CONFIG_DIR}' -perm /o+r -print 2>/dev/null | grep -q ."
check "no file under ${CONFIG_DIR} carries an execute bit" \
    bash -c "! find '${CONFIG_DIR}' -type f -perm /a+x -print 2>/dev/null | grep -q ."
check "no /etc/wazuh was created" bash -c "[ ! -e /etc/wazuh ]"
check "the service account cannot create a file in ${CONFIG_DIR}" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'touch ${CONFIG_DIR}/planted' 2>/dev/null && [ ! -e '${CONFIG_DIR}/planted' ]"
for d in certs export ca opensearch-security; do
    check "the service account cannot create a file in ${d}/" \
        bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'touch ${CONFIG_DIR}/${d}/planted' 2>/dev/null"
done
check "the service account cannot write opensearch.yml" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'echo x >> ${OPENSEARCH_YML}' 2>/dev/null"
check "the service account can read its own certificate and key" \
    as_service "cat '${CERTS_DIR}/indexer.pem' '${CERTS_DIR}/indexer-key.pem' '${CERTS_DIR}/root-ca.pem' > /dev/null"
check "the service account can read export/ca.pem" \
    as_service "cat '${EXPORT_DIR}/ca.pem' > /dev/null"
check "the service account cannot read the admin key" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'cat ${CERTS_DIR}/admin-key.pem' 2>/dev/null"
check "the service account cannot read the published passwords" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'cat ${CREDENTIALS}' 2>/dev/null"
check "the service account cannot read the CA key" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'cat ${CA_DIR}/root-ca.key' 2>/dev/null"

if [ "${PKG_KIND}" = "rpm" ]; then
    # Content changes to the configuration files are expected (the resolver writes digests and
    # DNs); an ownership (U, G) or mode (M) change means %files and %post disagree.
    verify=$(rpm -V wazuh-indexer 2>/dev/null | awk '{ flags = substr($0, 1, 9); if (flags ~ /[UGM]/) print }')
    if [ -z "${verify}" ]; then
        ok "rpm -V reports no ownership or mode change"
    else
        fail "rpm -V reports ownership or mode changes"
        printf '%s\n' "${verify}" | head -10 | sed 's/^/        /'
    fi
fi

section "1.1 Auto-generated passwords for the three internal users"

check_eq "credentials.env holds 3 indexer keys" "3" "$(cred_count)"
for key in WAZUH_INDEXER_ADMIN_PASSWORD WAZUH_INDEXER_KIBANASERVER_PASSWORD WAZUH_INDEXER_MANAGER_PASSWORD; do
    value="$(cred_get "${key}")" || value=""
    if [ -z "${value}" ]; then
        fail "${key} is present and non-empty"
        continue
    fi
    len=${#value}
    if [ "${len}" -lt 12 ] || [ "${len}" -gt 64 ]; then
        fail "${key} length ${len} is outside the 12-64 policy"
    elif ! printf '%s' "${value}" | grep -q '[A-Za-z]' || ! printf '%s' "${value}" | grep -q '[0-9]'; then
        fail "${key} lacks a letter or a digit (PCI DSS 8.3.6)"
    else
        ok "${key} present, ${len} chars, policy-compliant"
    fi
done

# Distinct values, or one leak compromises all three.
uniq_count=$(grep -E '^[[:space:]]*WAZUH_INDEXER_[A-Z_]+=' "${CREDENTIALS}" | cut -d= -f2- | sort -u | wc -l)
check_eq "the three passwords are distinct" "3" "${uniq_count}"

section "1.2 Auto-generated certificates"

for f in root-ca.pem indexer.pem indexer-key.pem admin.pem admin-key.pem; do
    check "certs/${f} exists" test -f "${CERTS_DIR}/${f}"
done
check "indexer.pem chains to the CA" \
    openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${CERTS_DIR}/indexer.pem"
check "indexer.pem chains to the published CA" \
    openssl verify -CAfile "${EXPORT_DIR}/ca.pem" "${CERTS_DIR}/indexer.pem"
check "admin.pem chains to the CA" \
    openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${CERTS_DIR}/admin.pem"
check_eq "indexer.pem carries the leaf followed by the CA" "2" \
    "$(grep -c 'BEGIN CERTIFICATE' "${CERTS_DIR}/indexer.pem")"
check "the CA names this host" \
    bash -c "openssl x509 -in '${CA_DIR}/root-ca.pem' -noout -subject | grep -q 'wazuh-indexer-$(short_hostname)'"
check "the CA is a CA" \
    bash -c "openssl x509 -in '${CA_DIR}/root-ca.pem' -noout -ext basicConstraints | grep -q 'CA:TRUE'"

sans=$(openssl x509 -in "${CERTS_DIR}/indexer.pem" -noout -text 2>/dev/null \
    | grep -A1 'Subject Alternative Name' | tail -1 | tr -d ' ')
info "SANs: ${sans}"
case "${sans}" in
    *'*.wazuh.indexer'*) fail "the shared wildcard SAN *.wazuh.indexer is still present" ;;
    *) ok "no shared wildcard SAN" ;;
esac
# openssl -text renders these as "IP Address:127.0.0.1", not "IP:127.0.0.1".
case "${sans}" in
    *'IPAddress:127.0.0.1'*|*'IP:127.0.0.1'*) ok "loopback is in the SAN list" ;;
    *) fail "loopback missing from the SAN list (localhost tooling will fail)" ;;
esac
case "${sans}" in
    *"DNS:$(short_hostname)"*) ok "this host's name is in the SAN list" ;;
    *) fail "hostname missing from the SAN list" ;;
esac

# A deployment that replaces the package certificates with wazuh-certs-tool's keeps admin_dn valid
# only while both issue the admin certificate with the same subject. Read from the tool this
# package ships: a literal here cannot notice the two drifting apart.
tool_subj=$(grep -o "admin\.csr.*-subj '[^']*'" "${WAZUH_TOOLS}/wazuh-certs-tool.sh" 2>/dev/null \
    | sed "s/.*-subj '//; s/'\$//")
if [ -z "${tool_subj}" ]; then
    skip "wazuh-certs-tool.sh is not shipped, or its admin subject could not be read"
else
    # openssl renders /A=1/B=2 as B=2,A=1, so the expected DN is the -subj arguments reversed.
    tool_dn=$(printf '%s' "${tool_subj}" | awk -F/ '{ for (i = NF; i > 1; i--) printf "%s%s", $i, (i > 2 ? "," : "\n") }')
    check_eq "the admin subject matches the one wazuh-certs-tool.sh issues" \
        "${tool_dn}" "$(subject_of "${CERTS_DIR}/admin.pem")"
fi

check_eq "the CA is trusted by the bundled JDK" "yes" "$(ca_is_trusted)"

section "1.3 What the package publishes for the manager and the dashboard"

check "export/ca.pem is the CA in ca/" same "${EXPORT_DIR}/ca.pem" "${CA_DIR}/root-ca.pem"
check "export/credentials.env starts with its header" \
    grep -q '^# Published by wazuh-indexer' "${CREDENTIALS}"
check "no serial file is kept beside the CA" bash -c "[ ! -e '${CA_DIR}/root-ca.srl' ]"
check "the shipped tools carry the indexer's helper" \
    bash -c "grep -q 'wazuh-indexer-credentials.sh ------' '${WAZUH_TOOLS}/wazuh-certs-tool.sh' && grep -q 'wazuh-indexer-credentials.sh ------' '${WAZUH_TOOLS}/wazuh-passwords-tool.sh'"
check "the shipped tools no longer name /etc/wazuh" \
    bash -c "! grep -qE '/etc/wazuh([^-a-z]|\$)' '${WAZUH_TOOLS}/wazuh-certs-tool.sh' '${WAZUH_TOOLS}/wazuh-passwords-tool.sh'"

section "1.3b Client pairs for the manager and the dashboard"

# The indexer trusts only its own CA, so it issues the client pairs the manager and the dashboard
# present to it, and publishes them for the consumer on this host. They grant no rights.
now=$(date -u +%s)
for consumer in manager dashboard; do
    pem="${EXPORT_DIR}/${consumer}-client.pem"; key="${EXPORT_DIR}/${consumer}-client-key.pem"
    check "export/${consumer}-client.pem is root:root 0600" is 600 "${pem}" root:root
    check "export/${consumer}-client-key.pem is root:root 0600" is 600 "${key}" root:root
    [ -f "${pem}" ] || continue
    check "${consumer} pair chains to the CA" openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${pem}"
    check "${consumer} pair chains to the published CA" openssl verify -CAfile "${EXPORT_DIR}/ca.pem" "${pem}"
    check_eq "${consumer} pair carries the leaf followed by the CA" "2" "$(grep -c 'BEGIN CERTIFICATE' "${pem}")"
    check_eq "${consumer} subject" "C=US,L=California,O=Wazuh,OU=Wazuh,CN=wazuh-${consumer}" "$(subject_of "${pem}")"
    check "${consumer} pair is for client authentication" \
        bash -c "openssl x509 -in '${pem}' -noout -ext extendedKeyUsage | grep -q 'TLS Web Client Authentication'"
    check "${consumer} pair names no host" \
        bash -c "! openssl x509 -in '${pem}' -noout -ext subjectAltName 2>/dev/null | grep -q 'DNS:\|IP'"
    check "${consumer} key matches its certificate" \
        bash -c "[ \"\$(openssl x509 -in '${pem}' -noout -pubkey | sha256sum)\" = \"\$(openssl pkey -in '${key}' -pubout | sha256sum)\" ]"
    check "${consumer} subject is in neither admin_dn nor nodes_dn" \
        bash -c "! grep -q 'CN=wazuh-${consumer}' '${OPENSEARCH_YML}'"
    notbefore=$(date -u -d "$(openssl x509 -in "${pem}" -noout -startdate | cut -d= -f2)" +%s)
    notafter=$(date -u -d "$(openssl x509 -in "${pem}" -noout -enddate | cut -d= -f2)" +%s)
    check "${consumer} pair is backdated one day" bash -c "[ $((now - notbefore)) -ge 82800 ] && [ $((now - notbefore)) -le 90000 ]"
    check "${consumer} pair is valid for ten years" bash -c "[ $((notafter - notbefore)) -ge 315446400 ] && [ $((notafter - notbefore)) -le 315705600 ]"
done
# The node's own certificates go through the same signing path.
for f in indexer.pem admin.pem; do
    notbefore=$(date -u -d "$(openssl x509 -in "${CERTS_DIR}/${f}" -noout -startdate | cut -d= -f2)" +%s)
    check "certs/${f} is backdated one day" bash -c "[ $((now - notbefore)) -ge 82800 ] && [ $((now - notbefore)) -le 90000 ]"
done
notbefore=$(date -u -d "$(openssl x509 -in "${CA_DIR}/root-ca.pem" -noout -startdate | cut -d= -f2)" +%s)
check "the CA is backdated one day" bash -c "[ $((now - notbefore)) -ge 82800 ] && [ $((now - notbefore)) -le 90000 ]"
check_eq "the node DN keeps its order" "C=US,L=California,O=Wazuh,OU=Wazuh,CN=$(short_hostname)" "$(subject_of "${CERTS_DIR}/indexer.pem")"
# What keeps a client certificate from being a credential.
check "the certificate authentication domain is disabled" \
    bash -c "awk '/clientcert_auth_domain:/{f=1} f && /http_enabled:/{print \$2; exit}' '${CONFIG_DIR}/opensearch-security/config.yml' | grep -qx false"
check "client certificates are not required by the HTTP layer" \
    bash -c "! grep -qE '^plugins.security.ssl.http.clientauth_mode:[[:space:]]*REQUIRE' '${OPENSEARCH_YML}'"

section "1.4 internal_users.yml and opensearch.yml"

placeholders=$(grep -c '\${WAZUH_INDEXER_' "${INTERNAL_USERS}" 2>/dev/null | head -1)
placeholders="${placeholders:-0}"
check_eq "no unresolved \${NAME} placeholders remain" "0" "${placeholders}"

digests=$(grep -cE 'hash: "\$2[aby]\$[0-9]{2}\$' "${INTERNAL_USERS}" 2>/dev/null | head -1)
digests="${digests:-0}"
check_eq "three bcrypt digests written" "3" "${digests}"

for user in admin kibanaserver wazuh-manager; do
    check "${user} is present in internal_users.yml" grep -q "^${user}:" "${INTERNAL_USERS}"
done
check "wazuh-readonly is gone" bash -c "! grep -q '^wazuh-readonly:' '${INTERNAL_USERS}'"

# Each digest must actually verify against the password that was published.
if have_bcrypt; then
    for pair in ${OWNED_PAIRS}; do
        u="${pair%%:*}"; k="${pair##*:}"
        if digest_verifies "$(hash_of "${u}")" "$(cred_get "${k}")"; then
            ok "${u} digest verifies against its published password"
        else
            fail "${u} digest does NOT match its published password"
        fi
    done
else
    skip "bcrypt verification (python3-bcrypt not installed)"
fi

node_dn=$(subject_of "${CERTS_DIR}/indexer.pem")
admin_dn=$(subject_of "${CERTS_DIR}/admin.pem")
check "nodes_dn carries this node's DN" grep -qF "${node_dn}" "${OPENSEARCH_YML}"
check "admin_dn carries the admin DN" grep -qF "${admin_dn}" "${OPENSEARCH_YML}"
check "no shipped CN=node-1 placeholder DN" bash -c "! grep -q 'CN=node-1,OU=Wazuh' '${OPENSEARCH_YML}'"

section "1.5 State file"

check "${MARKER} exists" test -f "${MARKER}"
check "${MARKER} is root's" is 600 "${MARKER}" root:root

section "1.6 The node starts"

systemctl start wazuh-indexer >/tmp/start.log 2>&1
START_RC=$?
check_eq "systemctl start succeeds" "0" "${START_RC}"
if wait_for_node; then
    ok "node answers on 9200"
else
    fail "node did not answer on 9200 within 120s"
    journalctl -u wazuh-indexer --no-pager 2>/dev/null | tail -20 | sed 's/^/        /'
fi

errs="$(service_errors)"
if [ -n "${errs}" ]; then
    fail "the service logged errors"
    printf '%s\n' "${errs}" | head -5 | sed 's/^/        /'
else
    ok "no errors in the service journal"
fi

warns="$(permission_warnings)"
if [ -n "${warns}" ]; then
    fail "the security plugin warned about file permissions in ${CONFIG_DIR}"
    printf '%s\n' "${warns}" | head -5 | sed 's/^/        /'
else
    ok "no insecure file permissions warning from the security plugin"
fi

# The node must not have written anything in the configuration directory: it is root's.
check "the node wrote nothing under ${CONFIG_DIR}" \
    bash -c "! find '${CONFIG_DIR}' ! -user root -print 2>/dev/null | grep -q ."

# Security configuration is pending: nothing has uploaded it yet, so the
# security plugin answers but authenticates nobody.
pending=$(curl -sk "${API}/" 2>/dev/null | head -c 200)
case "${pending}" in
    *"not initialized"*|*"Unauthorized"*)
        ok "security configuration is pending, as designed" ;;
    *)
        fail "unexpected pre-upload response: ${pending}" ;;
esac

section "1.7 indexer-security-init.sh, then API access"

if [ ! -x "${PRODUCT_DIR}/bin/indexer-security-init.sh" ]; then
    fail "indexer-security-init.sh is missing"
else
    "${PRODUCT_DIR}/bin/indexer-security-init.sh" >/tmp/secinit.log 2>&1
    check_eq "indexer-security-init.sh succeeds" "0" "$?"
    grep -q "Done with success" /tmp/secinit.log \
        && ok "securityadmin reported success" \
        || { fail "securityadmin did not report success"; tail -10 /tmp/secinit.log | sed 's/^/        /'; }
    check "securityadmin ran as root (no hsperfdata for the service account)" \
        bash -c "[ ! -e /tmp/hsperfdata_wazuh-indexer ] || [ \"\$(stat -c %U /tmp/hsperfdata_wazuh-indexer)\" != wazuh-indexer ]"
fi

for pair in "admin:WAZUH_INDEXER_ADMIN_PASSWORD:200" \
            "kibanaserver:WAZUH_INDEXER_KIBANASERVER_PASSWORD:200" \
            "wazuh-manager:WAZUH_INDEXER_MANAGER_PASSWORD:200"; do
    u=$(echo "${pair}" | cut -d: -f1)
    k=$(echo "${pair}" | cut -d: -f2)
    want=$(echo "${pair}" | cut -d: -f3)
    got=$(api_status "${u}" "$(cred_get "${k}")")
    # All three reach _cluster/health: wazuh_manager holds cluster_monitor. A
    # 403 would still prove authentication, so it is accepted as well.
    if [ "${got}" = "${want}" ] || [ "${got}" = "403" ]; then
        ok "${u} authenticates (HTTP ${got})"
    else
        fail "${u} expected HTTP ${want}, got ${got}"
    fi
done

# A client pair grants nothing by itself, and nothing more with the password.
for consumer in manager dashboard; do
    pem="${EXPORT_DIR}/${consumer}-client.pem"; key="${EXPORT_DIR}/${consumer}-client-key.pem"
    [ -f "${pem}" ] || continue
    got=$(curl -sk --cert "${pem}" --key "${key}" -o /dev/null -w '%{http_code}' "${API}/_cluster/health" 2>/dev/null)
    check_eq "the ${consumer} pair without a password is refused" "401" "${got}"
    got=$(curl -sk --cert "${pem}" --key "${key}" -o /dev/null -w '%{http_code}' "${API}/_plugins/_security/api/internalusers" 2>/dev/null)
    check_eq "the ${consumer} pair gives no access to the security API" "401" "${got}"
done
with_pw=$(api_status wazuh-manager "$(cred_get WAZUH_INDEXER_MANAGER_PASSWORD)")
with_both=$(curl -sk --cert "${EXPORT_DIR}/manager-client.pem" --key "${EXPORT_DIR}/manager-client-key.pem" -o /dev/null -w '%{http_code}' -u "wazuh-manager:$(cred_get WAZUH_INDEXER_MANAGER_PASSWORD)" "${API}/_cluster/health" 2>/dev/null)
check_eq "the manager pair with the password gives what the password alone gives" "${with_pw}" "${with_both}"
with_admin=$(curl -sk --cert "${EXPORT_DIR}/manager-client.pem" --key "${EXPORT_DIR}/manager-client-key.pem" -o /dev/null -w '%{http_code}' -u "wazuh-manager:$(cred_get WAZUH_INDEXER_MANAGER_PASSWORD)" "${API}/_plugins/_security/api/internalusers" 2>/dev/null)
check "the manager pair with the password is not an admin" bash -c "[ '${with_admin}' = 401 ] || [ '${with_admin}' = 403 ]"
# A pair from another CA fails the handshake.
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout /tmp/other-ca.key -out /tmp/other-ca.pem \
    -subj "/CN=other-ca" -addext "basicConstraints=critical,CA:TRUE" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout /tmp/other-client-key.pem -out /tmp/other-client.csr \
    -subj "/CN=wazuh-manager/OU=Wazuh/O=Wazuh/L=California/C=US" >/dev/null 2>&1
printf 'extendedKeyUsage = clientAuth\n' > /tmp/other-client.ext
openssl x509 -req -in /tmp/other-client.csr -CA /tmp/other-ca.pem -CAkey /tmp/other-ca.key \
    -set_serial "0x$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')" -days 365 -extfile /tmp/other-client.ext \
    -out /tmp/other-client.pem >/dev/null 2>&1
got=$(curl -sk --cert /tmp/other-client.pem --key /tmp/other-client-key.pem -o /dev/null -w '%{http_code}' "${API}/" 2>/dev/null)
check_eq "a client pair from another CA fails the handshake" "000" "${got}"
rm -f /tmp/other-ca.key /tmp/other-ca.pem /tmp/other-client-key.pem /tmp/other-client.csr /tmp/other-client.ext /tmp/other-client.pem

# The shipped defaults must be dead.
for pair in "admin:admin" "kibanaserver:kibanaserver" "wazuh-manager:wazuh-manager"; do
    u="${pair%%:*}"; p="${pair##*:}"
    got=$(api_status "${u}" "${p}")
    check_eq "${u}:${p} is rejected" "401" "${got}"
done

section "1.8 Resolution happens once — a restart changes nothing"

before=$(fingerprint "${CERTS_DIR}"/*.pem "${EXPORT_DIR}"/*.pem "${CREDENTIALS}" "${CA_DIR}/root-ca.pem" "${CA_DIR}/root-ca.key" "${KEYSTORE}" "${OPENSEARCH_YML}" "${INTERNAL_USERS}")
mv "${EXPORT_DIR}" "${EXPORT_DIR}.moved"
systemctl restart wazuh-indexer >/tmp/restart.log 2>&1
RESTART_RC=$?
check_eq "service restarts with export/ moved away" "0" "${RESTART_RC}"
if wait_for_node; then
    ok "node answers after the restart"
else
    fail "node did not come back after the restart"
    journalctl -u wazuh-indexer --no-pager -n 20 2>/dev/null | sed 's/^/        /'
fi
check "nothing was published again" bash -c "[ ! -e '${CREDENTIALS}' ]"
mv "${EXPORT_DIR}.moved" "${EXPORT_DIR}"
after=$(fingerprint "${CERTS_DIR}"/*.pem "${EXPORT_DIR}"/*.pem "${CREDENTIALS}" "${CA_DIR}/root-ca.pem" "${CA_DIR}/root-ca.key" "${KEYSTORE}" "${OPENSEARCH_YML}" "${INTERNAL_USERS}")
check_eq "no credential, keystore or certificate changed" "${before}" "${after}"

admin_pw="$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)"
wait_for_cluster admin "${admin_pw}"
check_eq "admin still authenticates after the restart" "200" "$(api_status admin "${admin_pw}")"

section "1.8b Planted trust material is refused before the service starts"

# The service account can plant nothing: the configuration directory is root's.
check "the service account cannot plant a link in export/" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'ln -s /etc/passwd ${EXPORT_DIR}/evil' 2>/dev/null; [ ! -L '${EXPORT_DIR}/evil' ]"
check "the service account cannot plant a certificate" \
    bash -c "! chroot --userspec=${NAME}:${NAME} --skip-chdir / /bin/sh -c 'cp ${CERTS_DIR}/indexer.pem ${CERTS_DIR}/evil.pem' 2>/dev/null; [ ! -e '${CERTS_DIR}/evil.pem' ]"

# What root finds planted -- a link, a group-writable file -- is refused by the pre-start check,
# the service does not start, and nothing is written through it.
SENTINEL=/root/.credentials-sentinel
printf 'untouched\n' > "${SENTINEL}"
chmod 600 "${SENTINEL}"
systemctl stop wazuh-indexer >/dev/null 2>&1
ln -s "${SENTINEL}" "${EXPORT_DIR}/evil"
out=$("${RESOLVER}" --check 2>&1); rc=$?
check_eq "--check refuses a link in export/" "1" "${rc}"
case "${out}" in
    *"UNSAFE ${EXPORT_DIR}/evil: a symbolic link"*) ok "it names the link" ;;
    *) fail "the refusal does not name the link: ${out}" ;;
esac
systemctl start wazuh-indexer >/dev/null 2>&1
check_eq "the service does not start with the link in place" "0" "$(node_running && echo 1 || echo 0)"
check_eq "the sentinel was not written through" "untouched" "$(cat "${SENTINEL}" 2>/dev/null)"
rm -f "${EXPORT_DIR}/evil" "${SENTINEL}"
chmod 660 "${CERTS_DIR}/indexer.pem"
out=$("${RESOLVER}" --check 2>&1); rc=$?
check_eq "--check refuses a group-writable certificate" "1" "${rc}"
chmod 640 "${CERTS_DIR}/indexer.pem"
cp -a "${EXPORT_DIR}/manager-client.pem" /tmp/manager-client.pem.saved
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout /tmp/evil-key.pem -out /tmp/evil.pem -subj "/CN=wazuh-manager" >/dev/null 2>&1
install -m 0600 -o root -g root /tmp/evil.pem "${EXPORT_DIR}/manager-client.pem"
out=$("${RESOLVER}" --check 2>&1); rc=$?
check_eq "--check refuses a published pair that does not chain to the CA" "1" "${rc}"
case "${out}" in
    *"INVALID ${EXPORT_DIR}/manager-client.pem"*) ok "it names the pair" ;;
    *) fail "the refusal does not name the pair" ;;
esac
cp -a /tmp/manager-client.pem.saved "${EXPORT_DIR}/manager-client.pem"
rm -f /tmp/manager-client.pem.saved /tmp/evil-key.pem /tmp/evil.pem
check "--check passes once the planted material is gone" "${RESOLVER}" --check
systemctl reset-failed wazuh-indexer >/dev/null 2>&1
systemctl start wazuh-indexer >/tmp/start2.log 2>&1
check_eq "the service starts again" "0" "$?"
wait_for_node && ok "node answers again" || fail "node did not come back"
wait_for_cluster admin "${admin_pw}"

section "1.9 Rotation with wazuh-passwords-tool.sh"

if [ ! -f "${WAZUH_TOOLS}/wazuh-passwords-tool.sh" ]; then
    skip "wazuh-passwords-tool.sh is not shipped in this package"
else
    NEW_PW='Rotated.Pass+2026x'
    # -p is a flag: the tool reads the password from standard input.
    printf '%s' "${NEW_PW}" | bash "${WAZUH_TOOLS}/wazuh-passwords-tool.sh" -u admin -p \
        >/tmp/rotate.log 2>&1
    ROTATE_RC=$?
    if [ "${ROTATE_RC}" != "0" ]; then
        fail "wazuh-passwords-tool.sh exited ${ROTATE_RC}"
        tail -10 /tmp/rotate.log | sed 's/^/        /'
    else
        ok "wazuh-passwords-tool.sh succeeded"
    fi
    sleep 5
    got=$(api_status admin "${NEW_PW}")
    check_eq "admin authenticates with the rotated password" "200" "${got}"
    check_eq "the rotated password is published in export/" "${NEW_PW}" "$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)"
    check "export/credentials.env is still root:root 0600" is 600 "${CREDENTIALS}" root:root

    systemctl restart wazuh-indexer >/dev/null 2>&1
    wait_for_node
    wait_for_cluster admin "${NEW_PW}"
    got=$(api_status admin "${NEW_PW}")
    check_eq "the rotated password survives a restart" "200" "${got}"
fi

section "1.10 --clear and re-resolution"

# A password lives in two places at once: published in export/credentials.env for the sibling
# components, and bcrypted into internal_users.yml for the node itself. The same is true of a
# certificate: the files in certs/, the DNs in opensearch.yml and the anchor in the JDK truststore
# are one thing. --clear has to take back every half, and the next run has to resolve every half
# again.
#
# This phase runs last because --clear leaves the node unable to start until it re-resolves. It
# hands the host back fully resolved for the removal phase that follows.

systemctl stop wazuh-indexer >/dev/null 2>&1

if [ ! -x "${RESOLVER}" ]; then
    skip "resolve-credentials.sh is not shipped in this package"
else
    "${RESOLVER}" --clear >/tmp/clear.log 2>&1
    check_eq "--clear succeeds" "0" "$?"

    for pair in ${OWNED_PAIRS}; do
        u="${pair%%:*}"; k="${pair##*:}"
        check_eq "${u} is back to its \${NAME} placeholder" "\${${k}}" "$(hash_of "${u}")"
    done

    check "the published passwords are gone" bash -c "[ ! -e '${CREDENTIALS}' ]"
    check "the published CA is gone" bash -c "[ ! -e '${EXPORT_DIR}/ca.pem' ]"
    check "the published client pairs are gone" bash -c "! ls '${EXPORT_DIR}'/*-client*.pem 2>/dev/null | grep -q ."
    check "the state file is gone" bash -c "[ ! -e '${MARKER}' ]"
    check "the certificates are gone" bash -c "[ ! -e '${CERTS_DIR}/indexer.pem' ]"
    check "the bootstrap CA is gone" bash -c "[ ! -e '${CA_DIR}/root-ca.key' ] && [ ! -e '${CA_DIR}/.wazuh-indexer-bootstrap-ca' ]"
    check_eq "the node DN is gone from opensearch.yml" "" "$(dn_list plugins.security.nodes_dn)"
    check_eq "the admin DN is gone from opensearch.yml" "" "$(dn_list plugins.security.authcz.admin_dn)"
    check "the DN settings themselves are kept" grep -q '^plugins.security.nodes_dn:' "${OPENSEARCH_YML}"
    check_eq "the CA is no longer trusted by the JDK" "no" "$(ca_is_trusted)"

    if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
        check "internal_users.yml is still valid YAML" \
            python3 -c "import yaml; yaml.safe_load(open('${INTERNAL_USERS}'))"
    else
        skip "YAML validation of internal_users.yml (python3-yaml not installed)"
    fi
    check "the other entries are untouched" grep -q '^_meta:' "${INTERNAL_USERS}"

    # --- A certificate pair that arrives after the package ------------------
    # How a bring-your-own-PKI deployment installs: the CA directory holds a trust anchor with no
    # signing key, so the install cannot issue anything, and the pair is staged before the first
    # start, with the ownership the specification asks for. The resolution has to finish then, not
    # stop at the passwords.
    install -d -m 0750 -o root -g wazuh-indexer "${CA_DIR}"
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/external-ca.key -out /tmp/external-ca.pem \
        -days 3650 -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=external-root-ca" \
        -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" \
        >/dev/null 2>&1
    install -m 0640 -o root -g wazuh-indexer /tmp/external-ca.pem "${CA_DIR}/root-ca.pem"

    out=$("${RESOLVER}" --prestart 2>&1); rc=$?
    check_eq "--prestart refuses to start a node with no certificates" "1" "${rc}"
    case "${out}" in
        *"MISSING TLS certificates"*) ok "it names the certificates" ;;
        *) fail "the failure does not name the certificates" ;;
    esac
    check "no state file while the node is unresolved" bash -c "[ ! -e '${MARKER}' ]"
    check "the staged anchor was published for the other components" same "${EXPORT_DIR}/ca.pem" /tmp/external-ca.pem
    check "no client pair is published without the CA key" bash -c "! ls '${EXPORT_DIR}'/*-client*.pem 2>/dev/null | grep -q ."

    for n in indexer admin; do
        cn="${n}"; [ "${n}" = "indexer" ] && cn="$(short_hostname)"
        openssl req -newkey rsa:2048 -keyout "/tmp/${n}-key.pem" -out "/tmp/${n}.csr" \
            -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=${cn}" >/dev/null 2>&1
        printf 'subjectAltName = DNS:%s,DNS:localhost,IP:127.0.0.1\n' "${cn}" > "/tmp/${n}.ext"
        openssl x509 -req -in "/tmp/${n}.csr" -CA /tmp/external-ca.pem -CAkey /tmp/external-ca.key \
            -set_serial "0x$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')" -out "/tmp/${n}.pem" -days 3650 \
            -extfile "/tmp/${n}.ext" >/dev/null 2>&1
    done
    # Staged the way the previous documentation said, service-owned: refused, with the fix named.
    install -m 0400 -o wazuh-indexer -g wazuh-indexer /tmp/indexer.pem "${CERTS_DIR}/indexer.pem"
    install -m 0400 -o wazuh-indexer -g wazuh-indexer /tmp/indexer-key.pem "${CERTS_DIR}/indexer-key.pem"
    out=$("${RESOLVER}" --prestart 2>&1); rc=$?
    check_eq "a service-owned staged pair is refused" "1" "${rc}"
    case "${out}" in
        *"UNSAFE ${CERTS_DIR}/indexer.pem"*) ok "it names the file and the owner" ;;
        *) fail "the refusal does not name the file" ;;
    esac
    # Staged as specified: root's, read by the service through its group.
    install -m 0640 -o root -g wazuh-indexer /tmp/indexer.pem "${CERTS_DIR}/indexer.pem"
    install -m 0640 -o root -g wazuh-indexer /tmp/indexer-key.pem "${CERTS_DIR}/indexer-key.pem"
    install -m 0600 -o root -g root /tmp/admin.pem "${CERTS_DIR}/admin.pem"
    install -m 0600 -o root -g root /tmp/admin-key.pem "${CERTS_DIR}/admin-key.pem"

    "${RESOLVER}" --prestart >/tmp/reresolve.log 2>&1
    check_eq "--prestart resolves once the pair is staged" "0" "$?"
    check "the anchor was copied beside the pair for the node" is 640 "${CERTS_DIR}/root-ca.pem" root:wazuh-indexer
    check_eq "nodes_dn is filled from the staged pair" \
        "$(subject_of "${CERTS_DIR}/indexer.pem")" "$(dn_list plugins.security.nodes_dn)"
    check_eq "admin_dn is filled from the staged pair" \
        "$(subject_of "${CERTS_DIR}/admin.pem")" "$(dn_list plugins.security.authcz.admin_dn)"
    check_eq "the staged anchor is trusted by the JDK" "yes" "$(ca_is_trusted)"
    check "the state file is written now that everything resolved" test -f "${MARKER}"
    check_eq "three passwords published again" "3" "$(cred_count)"

    if have_bcrypt; then
        for pair in ${OWNED_PAIRS}; do
            u="${pair%%:*}"; k="${pair##*:}"
            if digest_verifies "$(hash_of "${u}")" "$(cred_get "${k}")"; then
                ok "${u} digest matches the password published after --clear"
            else
                fail "${u} digest does NOT match the password published after --clear"
            fi
        done
    else
        skip "bcrypt verification after --clear (python3-bcrypt not installed)"
    fi

    # --- An operator's own DN list is never replaced -------------------------
    # write_distinguished_names replaces a key wholesale, which is right for a fresh install and
    # wrong for a cluster node whose operator has already listed every DN. Outside --install only
    # an empty key is filled.
    rm -f "${MARKER}"
    sed -i 's|^plugins.security.nodes_dn:|plugins.security.nodes_dn:\n- "CN=node-2,OU=Wazuh,O=Wazuh,L=California,C=US"|' \
        "${OPENSEARCH_YML}"
    before=$(dn_list plugins.security.nodes_dn | tr '\n' ' ')
    "${RESOLVER}" --prestart >/tmp/dnkeep.log 2>&1
    check_eq "the operator's node list survives a later resolution" \
        "${before}" "$(dn_list plugins.security.nodes_dn | tr '\n' ' ')"

    # --- A password the policy rejects, supplied in local.env ----------------
    # The message has to describe the rule that is actually enforced, which lives in
    # wazuh_password_validate, and name the file the operator has to correct.
    # From nothing: --clear takes back the passwords and the certificates, and the external
    # anchor staged above has no signing key, so it goes too, or nothing could be issued.
    rm -f "${MARKER}"
    "${RESOLVER}" --clear >/dev/null 2>&1
    rm -f "${CA_DIR}"/root-ca.* "${CERTS_DIR}"/*.pem
    printf "WAZUH_INDEXER_ADMIN_PASSWORD='MyCompanyPass2026'\n" > "${LOCAL_ENV}"
    chmod 600 "${LOCAL_ENV}"
    out=$("${RESOLVER}" --prestart 2>&1); rc=$?
    check_eq "a password without a symbol is refused" "1" "${rc}"
    case "${out}" in
        *"one uppercase letter, one lowercase letter, one digit and one symbol"*)
            ok "the refusal describes the rule that is enforced" ;;
        *) fail "the refusal describes a different rule than the one checked" ;;
    esac
    case "${out}" in
        *"correct it in ${LOCAL_ENV}"*) ok "the refusal names local.env" ;;
        *) fail "the refusal does not name local.env" ;;
    esac
    case "${out}" in
        *MyCompanyPass2026*) fail "the refusal printed the rejected value" ;;
        *) ok "the rejected value is never printed" ;;
    esac
    check "the other two passwords were published meanwhile" \
        bash -c "[ \"\$(grep -cE '^WAZUH_INDEXER_(KIBANASERVER|MANAGER)_PASSWORD=' '${CREDENTIALS}')\" = 2 ]"
    check "the certificates were issued meanwhile" test -f "${CERTS_DIR}/indexer.pem"

    # --- A password the operator supplies ------------------------------------
    printf "WAZUH_INDEXER_ADMIN_PASSWORD='Chosen.By.Operator1'\n" > "${LOCAL_ENV}"
    chmod 600 "${LOCAL_ENV}"
    "${RESOLVER}" --prestart >/tmp/supplied.log 2>&1
    check_eq "--prestart resolves with the corrected value" "0" "$?"
    check_eq "the supplied password is published" "Chosen.By.Operator1" "$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)"
    check "local.env is left exactly as the operator wrote it" \
        grep -qx "WAZUH_INDEXER_ADMIN_PASSWORD='Chosen.By.Operator1'" "${LOCAL_ENV}"
    check "the state file is written" test -f "${MARKER}"
    if have_bcrypt; then
        if digest_verifies "$(hash_of admin)" "Chosen.By.Operator1"; then
            ok "the admin digest matches the supplied password"
        else
            fail "the admin digest does NOT match the supplied password"
        fi
    fi
    rm -f "${LOCAL_ENV}"

    # --- A SAN list without the DNS:/IP: prefixes ----------------------------
    rm -f "${MARKER}"
    "${RESOLVER}" --clear >/dev/null 2>&1
    printf 'WAZUH_INDEXER_CERT_SANS=node-1.example.com,10.0.0.1\n' > "${LOCAL_ENV}"
    chmod 600 "${LOCAL_ENV}"
    out=$("${RESOLVER}" --prestart 2>&1); rc=$?
    check_eq "a SAN list without DNS:/IP: prefixes is refused" "1" "${rc}"
    case "${out}" in
        *"WAZUH_INDEXER_CERT_SANS must be a comma-separated list of DNS:<name> or IP:<address>"*) ok "the refusal names the variable and the format" ;;
        *) fail "the refusal does not explain the format" ;;
    esac
    check "no certificate was issued" bash -c "[ ! -e '${CERTS_DIR}/indexer.pem' ]"
    printf 'WAZUH_INDEXER_CERT_SANS=DNS:node-1.example.com,IP:10.0.0.1\n' > "${LOCAL_ENV}"
    "${RESOLVER}" --prestart >/tmp/sans.log 2>&1
    check_eq "--prestart resolves with the prefixed list" "0" "$?"
    check "the certificate carries the listed names" \
        bash -c "openssl x509 -in '${CERTS_DIR}/indexer.pem' -noout -ext subjectAltName | grep -q 'DNS:node-1.example.com' && openssl x509 -in '${CERTS_DIR}/indexer.pem' -noout -ext subjectAltName | grep -q '10.0.0.1'"
    rm -f "${LOCAL_ENV}"

    # --- A digest with nothing left to supply its password -------------------
    # The state --clear used to leave behind, and how an upgrade from a version that predates this
    # mechanism arrives. Resolution must not publish a new password over it, and must not refuse to
    # start the node either: the digest is a working credential for whoever set it.
    rm -f "${MARKER}"
    kept=$(hash_of admin)
    cp -a "${CREDENTIALS}" /tmp/credentials.env.saved
    rm -f "${CREDENTIALS}"
    for mode in --upgrade --prestart; do
        out=$("${RESOLVER}" "${mode}" 2>&1); rc=$?
        check_eq "${mode} succeeds over a digest nothing supplies any more" "0" "${rc}"
        check_eq "${mode} leaves the digest alone" "${kept}" "$(hash_of admin)"
        check_eq "${mode} publishes nothing over it" "0" "$(cred_count)"
        case "${out}" in
            *--clear*) ok "${mode} names the way out" ;;
            *) fail "${mode} does not say how to recover" ;;
        esac
        rm -f "${MARKER}"
    done
    cp -a /tmp/credentials.env.saved "${CREDENTIALS}"

    # Hand the host back fully resolved: the removal phase asserts on the CA and on the published
    # keys. The external anchor staged above has no signing key, so it goes first -- otherwise
    # --install has nothing to issue from, which is the very case this phase just exercised.
    "${RESOLVER}" --clear >/dev/null 2>&1
    rm -f "${CA_DIR}"/root-ca.* "${CERTS_DIR}"/*.pem /tmp/external-ca.key
    "${RESOLVER}" --install >/dev/null 2>&1
    check "certificates are reissued by --install" test -f "${CERTS_DIR}/indexer.pem"
    check "the CA is back" test -f "${CA_DIR}/root-ca.pem"
    check "the CA is published again" same "${EXPORT_DIR}/ca.pem" "${CA_DIR}/root-ca.pem"
    for consumer in manager dashboard; do
        check "the ${consumer} client pair chains to the new CA" \
            openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${EXPORT_DIR}/${consumer}-client.pem"
    done
    check_eq "three passwords published" "3" "$(cred_count)"
    check_eq "the CA is trusted again" "yes" "$(ca_is_trusted)"
    check "--check passes on the resolved host" "${RESOLVER}" --check
fi

section "1.11 SysV init script"

# The SysV path is what a host without systemd uses, and it reaches code systemd never runs.
INITD="/etc/init.d/wazuh-indexer"

if [ ! -x "${INITD}" ]; then
    skip "no SysV init script in this package"
else
    check "the start path runs the resolver" grep -q 'resolve-credentials.sh" --prestart' "${INITD}"
    check "the init script runs no host tool the package does not declare" \
        bash -c "! grep -vE '^[[:space:]]*#' '${INITD}' | grep -qE '(^|[^a-zA-Z_./-])(runuser|pgrep|pkill|ps|awk)([^a-zA-Z_-]|\$)'"

    # A start that cannot resolve must be refused, the way ExecStartPre refuses it under systemd,
    # rather than bringing the node up half-configured with nothing to say why. An anchor with no
    # signing key and no staged pair is the one state resolution cannot complete on its own.
    cp -a "${CREDENTIALS}" /tmp/credentials.env.sysv
    "${RESOLVER}" --clear >/dev/null 2>&1
    install -d -m 0750 -o root -g wazuh-indexer "${CA_DIR}"
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/sysv-ca.key -out /tmp/sysv-ca.pem \
        -days 3650 -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=external-root-ca" \
        -addext "basicConstraints=critical,CA:TRUE" >/dev/null 2>&1
    install -m 0640 -o root -g wazuh-indexer /tmp/sysv-ca.pem "${CA_DIR}/root-ca.pem"

    out=$("${INITD}" start 2>&1); rc=$?
    check_eq "SysV start is refused while the node cannot resolve" "1" "${rc}"
    if node_running; then fail "the node was started"; else ok "the node was not started"; fi

    rm -f "${CA_DIR}"/root-ca.* /tmp/sysv-ca.key /tmp/sysv-ca.pem
    cp -a /tmp/credentials.env.sysv "${CREDENTIALS}"
    "${RESOLVER}" --install >/dev/null 2>&1

    # stop() signals what it reads from pidfiles the service account owns. A pid that is not one of
    # ours must not be signalled: root would be killing whatever that account pointed it at.
    mkdir -p /run/wazuh-indexer
    sleep 600 &
    victim=$!
    printf '%s\n' "${victim}" > /run/wazuh-indexer/wazuh-engine.pid
    printf '%s\n' "${victim}" > /run/wazuh-indexer/wazuh-indexer.pid
    "${INITD}" stop >/dev/null 2>&1
    if kill -0 "${victim}" 2>/dev/null; then
        ok "a foreign pid in the pidfiles is not signalled"
    else
        fail "the init script killed a process that is not the indexer"
    fi
    kill "${victim}" 2>/dev/null
    rm -f /run/wazuh-indexer/wazuh-engine.pid
fi

section "1.12 Reinstalling the package keeps the CA trusted"

# cacerts is a packaged file, not a configuration file, so installing over an existing install
# replaces it and takes the wazuh-root-ca entry with it. Resolution is complete by then, so the
# maintainer script's own run is the only thing that can put it back.

check_eq "the CA is trusted before the reinstall" "yes" "$(ca_is_trusted)"
cert_before=$(subject_of "${CERTS_DIR}/indexer.pem")$(openssl x509 -in "${CERTS_DIR}/indexer.pem" -noout -serial 2>/dev/null)
creds_before=$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)
keystore_before=$(fingerprint "${KEYSTORE}")

if [ "${PKG_KIND}" = "deb" ]; then
    DEBIAN_FRONTEND=noninteractive dpkg -i "${PACKAGE}" >/tmp/reinstall.log 2>&1
else
    yum reinstall -y "${PACKAGE}" >/tmp/reinstall.log 2>&1 \
        || rpm -Uvh --replacepkgs "${PACKAGE}" >/tmp/reinstall.log 2>&1
fi
check_eq "the package reinstalls cleanly" "0" "$?"

# Resolution happens once, so nothing the first install resolved may change.
check_eq "the certificate is untouched" "${cert_before}" \
    "$(subject_of "${CERTS_DIR}/indexer.pem")$(openssl x509 -in "${CERTS_DIR}/indexer.pem" -noout -serial 2>/dev/null)"
check_eq "the published password is untouched" "${creds_before}" "$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)"
check_eq "the keystore is untouched" "${keystore_before}" "$(fingerprint "${KEYSTORE}")"
check_eq "the CA is trusted after the reinstall" "yes" "$(ca_is_trusted)"
check "the configuration directory is still root's" is 750 "${CONFIG_DIR}" root:wazuh-indexer
check "export/credentials.env is still root:root 0600" is 600 "${CREDENTIALS}" root:root

# ---------------------------------------------------------------------------
# 2. Removal
# ---------------------------------------------------------------------------

section "2. Removing wazuh-indexer"

systemctl stop wazuh-indexer >/dev/null 2>&1

if [ "${PKG_KIND}" = "deb" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get remove -y wazuh-indexer >/tmp/remove.log 2>&1 \
        || dpkg -r wazuh-indexer >/tmp/remove.log 2>&1
else
    yum remove -y wazuh-indexer >/tmp/remove.log 2>&1
fi
REMOVE_RC=$?
check_eq "package removes cleanly" "0" "${REMOVE_RC}"

# Package-manager chatter that is not this feature's business:
#   * dpkg notes directories it declined to remove
#   * rpm notes config files it saved as *.rpmsave
#   * rpm notes packaged files that are already gone. The content manager
#     deletes the shipped snapshot zip once it has consumed it, by design, so
#     rpm finds nothing to unlink at removal. dpkg tolerates that silently,
#     which is why it only ever shows on RPM. Reported below, not asserted,
#     since it predates this feature.
noise="directory .* not empty so not removed|Removing wazuh-indexer|saved as .*\\.rpmsave|remove failed: No such file or directory"
if grep -iE '\b(error|warning)\b' /tmp/remove.log 2>/dev/null | grep -qvE "${noise}"; then
    fail "removal emitted errors or warnings"
    grep -iE '\b(error|warning)\b' /tmp/remove.log | grep -vE "${noise}" | head -5 | sed 's/^/        /'
else
    ok "removal emitted no unexpected errors or warnings"
fi

check "no helper was stashed anywhere for the removal" \
    bash -c "[ ! -e '${DATA_DIR}/.wazuh-credentials.sh' ] && [ ! -e /etc/wazuh ]"

# A plain `remove` keeps everything the package published; only `purge` takes it back. Both
# behaviours are asserted so a change to either is visible.
if [ "${PKG_KIND}" = "deb" ]; then
    check_eq "remove keeps the published passwords (purge takes them)" "3" "$(cred_count)"
    check "remove keeps the CA" test -f "${CA_DIR}/root-ca.pem"
    check "remove keeps the state file" test -f "${MARKER}"

    if [ "${SKIP_PURGE}" = "1" ]; then
        skip "purge phase (SKIP_PURGE=1)"
    else
        section "2b. Purging wazuh-indexer"
        DEBIAN_FRONTEND=noninteractive apt-get purge -y wazuh-indexer >/tmp/purge.log 2>&1 \
            || dpkg -P wazuh-indexer >/tmp/purge.log 2>&1
        check_eq "package purges cleanly" "0" "$?"

        if grep -iE '\b(error|warning)\b' /tmp/purge.log 2>/dev/null | grep -qvE "${noise}"; then
            fail "purge emitted errors or warnings"
            grep -iE '\b(error|warning)\b' /tmp/purge.log | grep -vE "${noise}" | head -5 | sed 's/^/        /'
        else
            ok "purge emitted no unexpected errors or warnings"
        fi

        check "export/ is removed" bash -c "[ ! -e '${EXPORT_DIR}' ]"
        check "ca/ is removed" bash -c "[ ! -e '${CA_DIR}' ]"
        check "state file is removed" bash -c "[ ! -e '${MARKER}' ]"
        check "the certificates issued from the removed CA are removed" \
            bash -c "[ ! -e '${CERTS_DIR}/indexer.pem' ] && [ ! -e '${CERTS_DIR}/admin-key.pem' ]"
        check "the keystore is kept, handed to root" bash -c "[ ! -e '${KEYSTORE}' ] || [ \"\$(stat -c %U '${KEYSTORE}')\" = root ]"
        check "no /etc/wazuh was ever created" bash -c "[ ! -e /etc/wazuh ]"
    fi
else
    # RPM has no remove/purge distinction: %postun runs the whole thing.
    check "export/ is removed" bash -c "[ ! -e '${EXPORT_DIR}' ]"
    check "ca/ is removed" bash -c "[ ! -e '${CA_DIR}' ]"
    check "state file is removed" bash -c "[ ! -e '${MARKER}' ]"
    check "the certificates issued from the removed CA are removed" \
        bash -c "[ ! -e '${CERTS_DIR}/indexer.pem' ] && [ ! -e '${CERTS_DIR}/admin-key.pem' ]"
    check "the keystore is kept, handed to root" bash -c "[ ! -e '${KEYSTORE}' ] || [ \"\$(stat -c %U '${KEYSTORE}')\" = root ]"
    check "no /etc/wazuh was ever created" bash -c "[ ! -e /etc/wazuh ]"
fi

section "2c. No credential material outlives the package"

# The digests are not plaintext, but they are offline-crackable and they protect
# a cluster this host may still be able to reach. Nothing the package wrote
# should survive its removal.
# Scoped to what this feature causes. wazuh-passwords-tool.sh keeps its own
# dated copies under internalusers-backup/ whenever an operator rotates; that
# predates install-time resolution and is the tool's to clean up, so it is
# reported rather than asserted.
all_leftovers=$(grep -rlE '\$2[aby]\$[0-9]{2}\$' "${CONFIG_DIR}" 2>/dev/null)
leftovers=$(printf '%s\n' "${all_leftovers}" | grep -v '/internalusers-backup/' | grep -v '^$')
if [ -z "${leftovers}" ]; then
    ok "no bcrypt digests left under ${CONFIG_DIR}"
else
    fail "bcrypt digests survive removal"
    printf '%s\n' "${leftovers}" | sed 's/^/        /'
fi
printf '%s\n' "${all_leftovers}" | grep '/internalusers-backup/' | while read -r f; do
    [ -n "${f}" ] && info "note: ${f} holds digests (wazuh-passwords-tool.sh backup, pre-existing)"
done
check "no published password outlives the package" bash -c "[ ! -e '${CREDENTIALS}' ]"
check "no CA private key outlives the package" bash -c "[ ! -e '${CA_DIR}/root-ca.key' ]"

# Packaged files the software itself removed at runtime. Harmless to the removal,
# but the package manifest and the filesystem disagree about them.
for _log in /tmp/remove.log /tmp/purge.log; do
    [ -f "${_log}" ] || continue
    grep -oE "file [^ :]+: remove failed: No such file or directory" "${_log}" 2>/dev/null \
        | sed -e 's/^file //' -e 's/: remove failed.*//' | sort -u | while read -r missing; do
        [ -n "${missing}" ] && info "note: ${missing} was already gone at removal (deleted at runtime)"
    done
done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

section "Report"
printf '  passed:  %s\n' "${PASSED}"
printf '  failed:  %s\n' "${FAILED}"
printf '  skipped: %s\n' "${SKIPPED}"
if [ "${FAILED}" -gt 0 ]; then
    printf '\n  Failures:'
    printf '%b\n' "${FAILURES}"
fi

[ "${FAILED}" -gt 125 ] && exit 125
exit "${FAILED}"
