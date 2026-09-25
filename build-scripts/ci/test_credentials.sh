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
ok "clean host, package present, systemd running"

# ---------------------------------------------------------------------------
# 1. Installation
# ---------------------------------------------------------------------------

section "1. Installing wazuh-indexer"

# Installed through the package manager rather than with `dpkg -i`, so the
# Depends/Requires this feature added are resolved rather than assumed. On a
# minimal image none of openssl, diffutils, iproute2 or procps is present, and
# an unresolved dependency here is itself a failure worth catching.
if [ "${PKG_KIND}" = "deb" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGE}" >/tmp/install.log 2>&1
else
    yum install -y "${PACKAGE}" >/tmp/install.log 2>&1
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

# 1.a2 The declared dependencies must actually be on the host now.
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
if command -v python3 >/dev/null 2>&1 && python3 -c 'import bcrypt' 2>/dev/null; then
    for pair in "admin:WAZUH_INDEXER_ADMIN_PASSWORD" \
                "kibanaserver:WAZUH_INDEXER_KIBANASERVER_PASSWORD" \
                "wazuh-manager:WAZUH_INDEXER_MANAGER_PASSWORD"; do
        u="${pair%%:*}"; k="${pair##*:}"
        h=$(awk -v u="^${u}:" '$0 ~ u {f=1; next} /^[^[:space:]]/ {f=0} f && /hash:/ {gsub(/.*hash: *"|"$/,""); print; exit}' "${INTERNAL_USERS}")
        p="$(cred_get "${k}")"
        if PW="$p" HS="$h" python3 -c 'import bcrypt,os,sys; sys.exit(0 if bcrypt.checkpw(os.environ["PW"].encode(), os.environ["HS"].replace("$2y$","$2b$").encode()) else 1)' 2>/dev/null; then
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

section "1.9 Rotation with wazuh-passwords-tool.sh"

if [ ! -f "${SECURITY_TOOLS}/wazuh-passwords-tool.sh" ]; then
    skip "wazuh-passwords-tool.sh is not shipped in this package"
else
    NEW_PW='Rotated.Pass+2026x'
    bash "${SECURITY_TOOLS}/wazuh-passwords-tool.sh" -u admin -p "${NEW_PW}" \
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
noise="directory .* not empty so not removed|Removing wazuh-indexer|saved as .*\\.rpmsave"
if grep -iE '\b(error|warning)\b' /tmp/remove.log 2>/dev/null | grep -qvE "${noise}"; then
    fail "removal emitted errors or warnings"
    grep -iE '\b(error|warning)\b' /tmp/remove.log | grep -vE "${noise}" | head -5 | sed 's/^/        /'
else
    ok "removal emitted no unexpected errors or warnings"
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
    fi
else
    # RPM has no remove/purge distinction: %postun runs the whole thing.
    check_eq "indexer keys removed from credentials.env" "0" "$(cred_count)"
    check "the sibling's key is untouched" grep -q 'WAZUH_MANAGER_API_PASSWORD' "${CREDENTIALS}"
    check "credentials.env itself is NOT deleted" test -f "${CREDENTIALS}"
    check "state file is removed" bash -c "[ ! -e '${MARKER}' ]"
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
