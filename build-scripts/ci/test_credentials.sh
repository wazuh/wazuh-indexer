#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Acceptance tests for install-time credential and TLS resolution.
# See https://github.com/wazuh/wazuh-indexer/issues/1927
#
# Exercises the wazuh-indexer package end to end: that it generates its own
# passwords and certificates at install, that the node comes up, that the three
# internal users authenticate once an operator has uploaded the security
# configuration, that resolution never happens a second time, and that removal
# and purge take back exactly what they own.
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

WAZUH_DIR="/etc/wazuh"
CREDENTIALS="${WAZUH_DIR}/credentials.env"
CA_DIR="${WAZUH_DIR}/ca"
CONFIG_DIR="/etc/wazuh-indexer"
CERTS_DIR="${CONFIG_DIR}/certs"
INTERNAL_USERS="${CONFIG_DIR}/opensearch-security/internal_users.yml"
OPENSEARCH_YML="${CONFIG_DIR}/opensearch.yml"
DATA_DIR="/var/lib/wazuh-indexer"
MARKER="${DATA_DIR}/.initialized"
PRODUCT_DIR="/usr/share/wazuh-indexer"
SECURITY_TOOLS="${PRODUCT_DIR}/plugins/opensearch-security/tools"
WAZUH_TOOLS="${PRODUCT_DIR}/tools"
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
    printf '  \033[32mPASS\033[0m  %s\n' "$*"
}

fail() {
    FAILED=$((FAILED + 1))
    FAILURES="${FAILURES}\n  - $*"
    printf '  \033[31mFAIL\033[0m  %s\n' "$*"
}

skip() {
    SKIPPED=$((SKIPPED + 1))
    printf '  \033[33mSKIP\033[0m  %s\n' "$*"
}

info() {
    printf '        %s\n' "$*"
}

# check <description> <command...>
check() {
    _desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "${_desc}"; else fail "${_desc}"; fi
}

# check_eq <description> <expected> <actual>
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

# Read a key from the credentials file without sourcing it, and without relying
# on the shared helper being installed (removal tests run after it is gone).
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

# Journal lines the service emitted at ERROR level or above, excluding the ones
# a correct installation legitimately produces.
service_errors() {
    journalctl -u wazuh-indexer --no-pager 2>/dev/null \
        | grep -iE '\b(error|fatal|exception)\b' \
        | grep -viE 'ErrorFile|OnOutOfMemoryError|HeapDumpOnOutOfMemoryError|error_trace|no-error' \
        || true
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
if [ -e "${WAZUH_DIR}" ] || [ -e "${MARKER}" ]; then
    echo "FATAL: ${WAZUH_DIR} or ${MARKER} already exists; use a clean host" >&2
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
    grep -qF "/etc/wazuh/credentials.env" /tmp/install.log
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
check "the per-key progress lines are not in the install output" \
    bash -c "! grep -q 'published WAZUH_INDEXER' /tmp/install.log"

# 1.a2 Everything the resolver needs must be on the host. Since the list came
# out of the package's own Depends, a miss here means the package under-declares
# what it needs, not that the test forgot to install something.
for tool in openssl cmp ip hostname pgrep flock; do
    if command -v "${tool}" >/dev/null 2>&1; then
        ok "dependency provides ${tool}"
    else
        fail "${tool} is absent: a declared dependency did not resolve"
    fi
done

# 1.b The installer must not start or enable the service.
# `systemctl is-active` prints AND exits non-zero, so `|| echo` would append a
# second line rather than substitute one.
check_eq "service not started by the installer" "inactive" \
    "$(systemctl is-active wazuh-indexer 2>/dev/null | head -1)"
check_eq "service not enabled by the installer" "disabled" \
    "$(systemctl is-enabled wazuh-indexer 2>/dev/null | head -1)"

section "1.0 Ownership: the service account cannot rewrite what root runs"

# Root executes bin/resolve-credentials.sh and sources lib/wazuh-credentials.sh.
# If the service account owned either, it could have root run its own code.
for f in "${PRODUCT_DIR}/bin/resolve-credentials.sh" "${PRODUCT_DIR}/lib/wazuh-credentials.sh"; do
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
    if runuser -u wazuh-indexer -- test -w "${writable}" 2>/dev/null; then
        ok "$(basename "${writable}") is still writable by the service account"
    else
        fail "$(basename "${writable}") is no longer writable by the service account"
    fi
done

# The service-owned trees. %defattr / the product-tree chown are package-wide, so
# these have to be handed back explicitly; a root-owned DATA_DIR stops the node
# creating nodes/ and it dies in NodeEnvironment before anything else runs.
for owned in "${DATA_DIR}" "${CONFIG_DIR}" /var/log/wazuh-indexer; do
    [ -d "${owned}" ] || continue
    if runuser -u wazuh-indexer -- test -w "${owned}" 2>/dev/null; then
        ok "${owned} is writable by the service account"
    else
        fail "${owned} is not writable by the service account (the node will not start)"
    fi
done

# securityadmin.sh is executed via `runuser wazuh-indexer`, so group execute has
# to survive the owner change.
sa="${SECURITY_TOOLS}/securityadmin.sh"
if [ -f "${sa}" ]; then
    if runuser -u wazuh-indexer -- test -x "${sa}" 2>/dev/null; then
        ok "securityadmin.sh is executable by the service account"
    else
        fail "securityadmin.sh is not executable by the service account (indexer-security-init.sh would fail)"
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

# Assert certificates permissions.
for f in root-ca.pem indexer.pem indexer-key.pem admin.pem admin-key.pem; do
    [ -f "${CERTS_DIR}/${f}" ] || continue
    _m=$(mode_of "${CERTS_DIR}/${f}")
    case "${_m}" in
        ?00) ok "certs/${f} is owner-only (mode ${_m})" ;;
        *)   fail "certs/${f} is readable by group or others (mode ${_m}); the plugin warns on every start" ;;
    esac
    check_eq "certs/${f} is owned by the service account" "wazuh-indexer:wazuh-indexer" \
        "$(owner_of "${CERTS_DIR}/${f}")"
done
check "indexer.pem chains to the CA" \
    openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${CERTS_DIR}/indexer.pem"
check "admin.pem chains to the CA" \
    openssl verify -CAfile "${CA_DIR}/root-ca.pem" "${CERTS_DIR}/admin.pem"

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
    *"DNS:$(hostname -s)"*) ok "this host's name is in the SAN list" ;;
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

# The CA private key must never be readable by anything but root.
if [ -f "${CA_DIR}/root-ca.key" ]; then
    check_eq "root-ca.key is 0400" "400" "$(mode_of "${CA_DIR}/root-ca.key")"
    check_eq "root-ca.key is root-owned" "root:root" "$(owner_of "${CA_DIR}/root-ca.key")"
else
    skip "root-ca.key absent (externally issued CA)"
fi

section "1.3 /etc/wazuh, credentials.env and root-ca.pem"

check "${WAZUH_DIR} exists" test -d "${WAZUH_DIR}"
check_eq "${WAZUH_DIR} is 0700" "700" "$(mode_of "${WAZUH_DIR}")"
check_eq "${WAZUH_DIR} is root-owned" "root:root" "$(owner_of "${WAZUH_DIR}")"
check "credentials.env exists" test -f "${CREDENTIALS}"
check_eq "credentials.env is 0600" "600" "$(mode_of "${CREDENTIALS}")"
check_eq "credentials.env is root-owned" "root:root" "$(owner_of "${CREDENTIALS}")"
check "CA anchor exists" test -f "${CA_DIR}/root-ca.pem"
check_eq "CA directory is 0700" "700" "$(mode_of "${CA_DIR}")"

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

node_dn=$(openssl x509 -in "${CERTS_DIR}/indexer.pem" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//')
admin_dn=$(openssl x509 -in "${CERTS_DIR}/admin.pem" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= *//')
check "nodes_dn carries this node's DN" grep -qF "${node_dn}" "${OPENSEARCH_YML}"
check "admin_dn carries the admin DN" grep -qF "${admin_dn}" "${OPENSEARCH_YML}"
check "no shipped CN=node-1 placeholder DN" bash -c "! grep -q 'CN=node-1,OU=Wazuh' '${OPENSEARCH_YML}'"

section "1.5 State file"

check "${MARKER} exists" test -f "${MARKER}"

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

# Security configuration is pending: nothing has uploaded it yet, so the
# security plugin answers but authenticates nobody.
pending=$(curl -sk "${API}/" 2>/dev/null | head -c 200)
case "${pending}" in
    *"not initialized"*|*"Unauthorized"*|*"OpenSearch Security not initialized"*)
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

# The shipped defaults must be dead.
for pair in "admin:admin" "kibanaserver:kibanaserver" "wazuh-manager:wazuh-manager"; do
    u="${pair%%:*}"; p="${pair##*:}"
    got=$(api_status "${u}" "${p}")
    check_eq "${u}:${p} is rejected" "401" "${got}"
done

section "1.8 Resolution happens once — /etc/wazuh unavailable"

mv "${WAZUH_DIR}" "${WAZUH_DIR}.moved"
systemctl restart wazuh-indexer >/tmp/restart.log 2>&1
RESTART_RC=$?
check_eq "service restarts with ${WAZUH_DIR} gone" "0" "${RESTART_RC}"
if wait_for_node; then
    ok "node answers after restart without ${WAZUH_DIR}"
else
    fail "node did not come back after restart without ${WAZUH_DIR}"
    journalctl -u wazuh-indexer --no-pager -n 20 2>/dev/null | sed 's/^/        /'
fi
check "no ${WAZUH_DIR} was recreated" bash -c "[ ! -e '${WAZUH_DIR}/credentials.env' ]"
mv "${WAZUH_DIR}.moved" "${WAZUH_DIR}"

admin_pw="$(cred_get WAZUH_INDEXER_ADMIN_PASSWORD)"
wait_for_cluster admin "${admin_pw}"
check_eq "admin still authenticates after the restart" "200" "$(api_status admin "${admin_pw}")"

section "1.8b Symlink clobber: a planted .tmp must not redirect a root write"

# /etc/wazuh-indexer and its opensearch-security/ subdir stay service-owned, so
# the service account can pre-create files there. The resolver runs as root; a
# fixed, guessable scratch name would let it be pointed at any file on the host.
SENTINEL=/root/.credentials-sentinel
printf 'untouched\n' > "${SENTINEL}"
chmod 600 "${SENTINEL}"

runuser -u wazuh-indexer -- ln -sf "${SENTINEL}" "${INTERNAL_USERS}.tmp" 2>/dev/null
runuser -u wazuh-indexer -- ln -sf "${SENTINEL}" "${OPENSEARCH_YML}.tmp" 2>/dev/null

if [ -L "${INTERNAL_USERS}.tmp" ] || [ -L "${OPENSEARCH_YML}.tmp" ]; then
    # Force a full re-resolution so both write paths run.
    rm -f "${MARKER}"
    "${PRODUCT_DIR}/bin/resolve-credentials.sh" --prestart >/tmp/symlink.log 2>&1 || true

    if [ "$(cat "${SENTINEL}" 2>/dev/null)" = "untouched" ]; then
        ok "a planted .tmp symlink did not redirect the resolver's write"
    else
        fail "the resolver followed a symlink and overwrote ${SENTINEL}"
    fi
    rm -f "${INTERNAL_USERS}.tmp" "${OPENSEARCH_YML}.tmp"
else
    skip "symlink clobber (could not pre-create the .tmp paths as the service account)"
fi
rm -f "${SENTINEL}"

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

    systemctl restart wazuh-indexer >/dev/null 2>&1
    wait_for_node
    wait_for_cluster admin "${NEW_PW}"
    got=$(api_status admin "${NEW_PW}")
    check_eq "the rotated password survives a restart" "200" "${got}"
fi

section "1.10 --clear and re-resolution"

# A password lives in two places at once: published in credentials.env for the sibling components,
# and bcrypted into internal_users.yml for the node itself. The same is true of a certificate: the
# files in certs/, the DNs in opensearch.yml and the anchor in the JDK truststore are one thing.
# --clear has to take back every half, and the next run has to resolve every half again.
#
# This phase runs last because --clear leaves the node unable to start until it re-resolves. It
# hands the host back fully resolved for the removal phase that follows.

systemctl stop wazuh-indexer >/dev/null 2>&1

RESOLVER="${PRODUCT_DIR}/bin/resolve-credentials.sh"

if [ ! -x "${RESOLVER}" ]; then
    skip "resolve-credentials.sh is not shipped in this package"
else
    "${RESOLVER}" --clear >/tmp/clear.log 2>&1
    check_eq "--clear succeeds" "0" "$?"

    for pair in ${OWNED_PAIRS}; do
        u="${pair%%:*}"; k="${pair##*:}"
        check_eq "${u} is back to its \${NAME} placeholder" "\${${k}}" "$(hash_of "${u}")"
    done

    check_eq "the indexer's published passwords are gone" "0" "$(cred_count)"
    check "the state file is gone" bash -c "[ ! -e '${MARKER}' ]"
    check "the certificates are gone" bash -c "[ ! -e '${CERTS_DIR}/indexer.pem' ]"
    check "the bootstrap CA is gone" bash -c "[ ! -e '${CA_DIR}/root-ca.key' ]"
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
    # start. The resolution has to finish then, not stop at the passwords.
    mkdir -p "${CA_DIR}" && chmod 700 "${CA_DIR}"
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/external-ca.key -out "${CA_DIR}/root-ca.pem" \
        -days 3650 -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=external-root-ca" \
        >/dev/null 2>&1
    chmod 644 "${CA_DIR}/root-ca.pem"

    out=$("${RESOLVER}" --prestart 2>&1); rc=$?
    check_eq "--prestart refuses to start a node with no certificates" "1" "${rc}"
    case "${out}" in
        *"MISSING TLS certificates"*) ok "it names the certificates" ;;
        *) fail "the failure does not name the certificates" ;;
    esac
    check "no state file while the node is unresolved" bash -c "[ ! -e '${MARKER}' ]"

    for n in indexer admin; do
        cn="${n}"; [ "${n}" = "indexer" ] && cn="$(hostname -s)"
        openssl req -newkey rsa:2048 -keyout "${CERTS_DIR}/${n}-key.pem" -out "/tmp/${n}.csr" \
            -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=${cn}" >/dev/null 2>&1
        openssl x509 -req -in "/tmp/${n}.csr" -CA "${CA_DIR}/root-ca.pem" -CAkey /tmp/external-ca.key \
            -CAcreateserial -out "${CERTS_DIR}/${n}.pem" -days 3650 >/dev/null 2>&1
    done
    cp "${CA_DIR}/root-ca.pem" "${CERTS_DIR}/root-ca.pem"
    chmod 400 "${CERTS_DIR}"/*.pem
    chown wazuh-indexer:wazuh-indexer "${CERTS_DIR}"/*.pem

    "${RESOLVER}" --prestart >/tmp/reresolve.log 2>&1
    check_eq "--prestart resolves once the pair is staged" "0" "$?"
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
    rm -f "${CA_DIR}"/root-ca.* /tmp/external-ca.key
    "${RESOLVER}" --install >/dev/null 2>&1
    check "certificates are reissued by --install" test -f "${CERTS_DIR}/indexer.pem"
    check "the CA is back" test -f "${CA_DIR}/root-ca.pem"
    check_eq "three passwords published" "3" "$(cred_count)"
    check_eq "the CA is trusted again" "yes" "$(ca_is_trusted)"
fi

section "1.11 SysV init script"

# The SysV path is what a host without systemd uses, and it reaches code systemd never runs.
INITD="/etc/init.d/wazuh-indexer"

if [ ! -x "${INITD}" ]; then
    skip "no SysV init script in this package"
else
    check "the start path runs the resolver" grep -q 'resolve-credentials.sh" --prestart' "${INITD}"

    # A start that cannot resolve must be refused, the way ExecStartPre refuses it under systemd,
    # rather than bringing the node up half-configured with nothing to say why. An anchor with no
    # signing key and no staged pair is the one state resolution cannot complete on its own.
    cp -a "${CREDENTIALS}" /tmp/credentials.env.sysv
    "${RESOLVER}" --clear >/dev/null 2>&1
    mkdir -p "${CA_DIR}" && chmod 700 "${CA_DIR}"
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/sysv-ca.key -out "${CA_DIR}/root-ca.pem" \
        -days 3650 -nodes -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=external-root-ca" \
        >/dev/null 2>&1
    chmod 644 "${CA_DIR}/root-ca.pem"

    out=$("${INITD}" start 2>&1); rc=$?
    check_eq "SysV start is refused while the node cannot resolve" "1" "${rc}"
    # The bracket keeps pgrep from matching the pattern inside this very command line.
    check "the node was not started" bash -c "! pgrep -f '[o]rg.opensearch.bootstrap.OpenSearch' >/dev/null"

    rm -f "${CA_DIR}"/root-ca.* /tmp/sysv-ca.key
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
check_eq "the CA is trusted after the reinstall" "yes" "$(ca_is_trusted)"

# ---------------------------------------------------------------------------
# 2. Removal
# ---------------------------------------------------------------------------

section "2. Removing wazuh-indexer"

# A sibling's key, to prove removal takes only what it owns.
printf "WAZUH_MANAGER_API_PASSWORD='Sibling.Key+01'\n" >> "${CREDENTIALS}"

systemctl stop wazuh-indexer >/dev/null 2>&1

if [ "${PKG_KIND}" = "deb" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get remove -y wazuh-indexer >/tmp/remove.log 2>&1 \
        || dpkg -r wazuh-indexer >/tmp/remove.log 2>&1
else
    yum remove -y wazuh-indexer >/tmp/remove.log 2>&1
fi
REMOVE_RC=$?
check_eq "package removes cleanly" "0" "${REMOVE_RC}"

# dpkg always notes directories it declined to remove because something
# unpackaged is still in them; that is not a fault of this feature.
# dpkg notes directories it declined to remove; rpm notes config files it saved.
# Both are ordinary package-manager behaviour. Whether the saved copies leak
# anything is asserted separately below, on their contents rather than on the
# message.
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

# The purge path sources the shared helper as root, from a copy the removal left behind. That copy
# must never sit where the service account can write, or the account chooses what root runs.
check "no root-sourced helper in the service-writable data directory" \
    bash -c "[ ! -e '${DATA_DIR}/.wazuh-credentials.sh' ]"

STASH="${WAZUH_DIR}/.wazuh-indexer-credentials.sh"
if [ -e "${STASH}" ]; then
    check_eq "the stashed helper is root-owned" "root:root" "$(owner_of "${STASH}")"
    check_eq "the stashed helper is 0600" "600" "$(mode_of "${STASH}")"
    check_eq "its directory is root-owned and root-only" "root:root 700" \
        "$(owner_of "${WAZUH_DIR}") $(mode_of "${WAZUH_DIR}")"
else
    info "no stashed helper after removal (expected on RPM, which purges in one step)"
fi

# Per the epic, a plain `remove` keeps everything; only `purge` takes the keys
# back. Both behaviours are asserted so a change to either is visible.
if [ "${PKG_KIND}" = "deb" ]; then
    check_eq "remove keeps the indexer keys (purge takes them)" "3" "$(cred_count)"
    check "remove keeps credentials.env" test -f "${CREDENTIALS}"
    check "remove keeps the CA" test -f "${CA_DIR}/root-ca.pem"

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

        check_eq "indexer keys removed from credentials.env" "0" "$(cred_count)"
        check "the sibling's key is untouched" grep -q 'WAZUH_MANAGER_API_PASSWORD' "${CREDENTIALS}"
        check "credentials.env itself is NOT deleted" test -f "${CREDENTIALS}"
        check "state file is removed" bash -c "[ ! -e '${MARKER}' ]"
        check "the CA survives while a sibling key remains" test -f "${CA_DIR}/root-ca.pem"
        check "the stashed helper is gone" bash -c "[ ! -e '${STASH}' ]"
    fi
else
    # RPM has no remove/purge distinction: %postun runs the whole thing.
    check_eq "indexer keys removed from credentials.env" "0" "$(cred_count)"
    check "the sibling's key is untouched" grep -q 'WAZUH_MANAGER_API_PASSWORD' "${CREDENTIALS}"
    check "credentials.env itself is NOT deleted" test -f "${CREDENTIALS}"
    check "state file is removed" bash -c "[ ! -e '${MARKER}' ]"
    check "the stashed helper is gone" bash -c "[ ! -e '${STASH}' ]"
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

# Packaged files the software itself removed at runtime. Harmless to the removal,
# but the package manifest and the filesystem disagree about them.
for _log in /tmp/remove.log /tmp/purge.log; do
    [ -f "${_log}" ] || continue
    grep -oE "file [^ :]+: remove failed: No such file or directory" "${_log}" 2>/dev/null \
        | sed -e 's/^file //' -e 's/: remove failed.*//' | sort -u | while read -r missing; do
        [ -n "${missing}" ] && info "note: ${missing} was already gone at removal (deleted at runtime)"
    done
done

# Pre-existing: the certificates directory is not owned by the package manifest,
# so a private key placed there outlives removal. Reported, not asserted, since
# it predates this feature and an operator may legitimately want the pair back.
for key in "${CERTS_DIR}/indexer-key.pem" "${CERTS_DIR}/admin-key.pem"; do
    [ -f "${key}" ] && info "note: ${key} still present after removal (pre-existing behaviour)"
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
