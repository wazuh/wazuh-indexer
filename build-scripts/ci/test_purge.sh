#!/bin/bash
# Verifies that purging the package takes back what its maintainer scripts
# created, that nothing it leaves in its own directories can be inherited by
# another account, and that a reinstall over what it kept comes back as it was.
# See https://github.com/wazuh/wazuh-indexer/issues/1951
#
# The purge manages the package's default directories -- /etc/wazuh-indexer,
# /usr/share/wazuh-indexer, /var/lib/wazuh-indexer and /var/log/wazuh-indexer --
# and nothing else, and it always removes the wazuh-indexer user and group.
#
# Five scenarios, run one after the other on the same host:
#
#   1. Fresh install, then purge. Nothing is left: no user, no group, no data
#      or configuration directory, no CA and no certificate issued from it, and
#      no "not empty" warning from the package manager.
#   2. A node that has been used, then purge. Index data, logs, the keystore, a
#      snapshot repository at a custom path.repo and a planted symlink stand in
#      for a node that ran. What the account owned in the default directories
#      belongs to root and keeps its mode, and each of those directories is
#      closed to everyone but root. The certificates issued from the removed CA
#      are removed with it. The custom snapshot repository and the symlink's
#      target are not touched.
#   3. Reinstall. Everything kept comes back with the owner and mode it had
#      before the purge, and the node's certificates chain to the CA it trusts.
#   4. A default directory the purge cannot hand over (a read-only mount), then
#      purge. The user and group are still removed, the purge names that
#      directory, and it does not claim to have kept it for root.
#   5. A certificate pair the CA did not issue -- the operator's own. The
#      resolver refuses it while the CA directory holds another CA, the purge
#      keeps it, a reinstall with nothing to verify it against reports it
#      instead of minting a CA, and staging the CA that issued it resolves.
#
# Required env:
#   PACKAGE_MANAGER   — "rpm" or "deb"
#   PACKAGE_NAME      — filename of the package under /artifacts/dist/
#
# Requirements: root and a throwaway host (container, VM) without a previous
# wazuh-indexer installation.

set -uo pipefail

: "${PACKAGE_MANAGER:?PACKAGE_MANAGER is required (rpm or deb)}"
: "${PACKAGE_NAME:?PACKAGE_NAME is required}"

name="wazuh-indexer"
package="/artifacts/dist/${PACKAGE_NAME}"
config_dir="/etc/${name}"
certs_dir="${config_dir}/certs"
data_dir="/var/lib/${name}"
log_dir="/var/log/${name}"
product_dir="/usr/share/${name}"
default_dirs=("${config_dir}" "${product_dir}" "${data_dir}" "${log_dir}")
ca_dir="/etc/wazuh/ca"
marker="${data_dir}/.initialized"
resolver="${product_dir}/bin/resolve-credentials.sh"
repo_dir="/srv/${name}-repo"
canary="/etc/${name}-canary"
note="Directories set elsewhere in opensearch.yml (a custom path.data, path.logs or path.repo) are left as they are"
failed=0

ok()   { echo "  ok:   $*"; }
fail() { echo "  FAIL: $*"; failed=$((failed + 1)); }
die()  { echo "ERROR: $*" >&2; exit 1; }

check() {
    local description="$1"; shift
    if "$@"; then ok "${description}"; else fail "${description}"; fi
}

not()          { ! "$@"; }
user_exists()  { getent passwd "${name}" > /dev/null 2>&1; }
group_exists() { getent group "${name}" > /dev/null 2>&1; }
output_has()   { grep -qF -- "$1" <<< "${purge_out}"; }
owned_by()     { [ "$(stat -c '%U:%G' "$2")" = "$1" ]; }
installed() {
    case "$PACKAGE_MANAGER" in
        rpm) rpm -q "${name}" > /dev/null 2>&1 ;;
        deb) dpkg-query -W -f='${db:Status-Status}' "${name}" 2>/dev/null | grep -qvx 'not-installed' ;;
    esac
}
verifies() { openssl verify -CAfile "$2" "$1" > /dev/null 2>&1; }

# Prints every file under the given paths that still carries an owner or group
# with no account behind it.
orphans() {
    local existing=()
    for p in "$@"; do [ -e "${p}" ] && existing+=("${p}"); done
    [ ${#existing[@]} -gt 0 ] || return 0
    find -P "${existing[@]}" \( -nouser -o -nogroup \) 2>/dev/null
}

# Prints mode, owner and path of everything in the default directories except
# the packaged trees, which the package manager rewrites anyway.
listing() {
    for d in "${default_dirs[@]}"; do
        [ -e "${d}" ] || continue
        find -P "${d}" \( -path "${product_dir}/jdk" -o -path "${product_dir}/lib" \
            -o -path "${product_dir}/modules" -o -path "${product_dir}/plugins" \
            -o -path "${product_dir}/engine" \) -prune -o -printf '%m %u:%g %p\n'
    done | sort -k3
}

# A CA and a pair issued from it, in $1, standing in for an operator's own PKI.
external_pki() {
    local dir="$1"
    mkdir -p "${dir}"
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "${dir}/root-ca.key" \
        -out "${dir}/root-ca.pem" -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=external-root-ca" \
        > /dev/null 2>&1
    for n in indexer admin; do
        cn="${n}"; [ "${n}" = "indexer" ] && cn="$(hostname -s)"
        openssl req -newkey rsa:2048 -nodes -keyout "${dir}/${n}-key.pem" -out "${dir}/${n}.csr" \
            -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=${cn}" > /dev/null 2>&1
        openssl x509 -req -in "${dir}/${n}.csr" -CA "${dir}/root-ca.pem" -CAkey "${dir}/root-ca.key" \
            -CAcreateserial -days 3650 -out "${dir}/${n}.pem" > /dev/null 2>&1
    done
}

# Sets install_out.
install_package() {
    case "$PACKAGE_MANAGER" in
        rpm)
            install_out=$(yum localinstall -y "${package}" 2>&1)
            ;;
        deb)
            export DEBIAN_FRONTEND=noninteractive
            if [ -z "${deps_installed:-}" ]; then
                bash "$(dirname "$0")/install_package_dependencies.sh" "${package}" > /dev/null || return 1
                deps_installed=1
            fi
            install_out=$(dpkg -i "${package}" 2>&1)
            ;;
    esac || { echo "${install_out}"; die "installation failed"; }
    echo "${install_out}" | grep -E 'resolve-credentials' || true

    # The checks after a purge are only meaningful if installation created these.
    user_exists || die "installation did not create the ${name} user"
    group_exists || die "installation did not create the ${name} group"
    [ -d "${data_dir}/tmp" ] || die "installation did not create ${data_dir}/tmp"
}

# Sets purge_out and purge_rc.
purge_package() {
    case "$PACKAGE_MANAGER" in
        rpm) purge_out=$(yum remove -y "${name}" 2>&1) ;;
        deb) purge_out=$(apt-get purge -y "${name}" 2>&1) ;;
    esac
    purge_rc=$?
    echo "${purge_out}" | grep -E 'Kept|Some files|Note:|Directories set' || true
}

check_purged() {
    check "package purged cleanly" [ "${purge_rc}" -eq 0 ]
    check "package is no longer installed" not installed
    check "the ${name} user is removed" not user_exists
    check "the ${name} group is removed" not group_exists
}

case "$PACKAGE_MANAGER" in
    rpm|deb) ;;
    *) die "unknown PACKAGE_MANAGER '${PACKAGE_MANAGER}' — expected 'rpm' or 'deb'" ;;
esac

if user_exists || group_exists; then
    die "${name} user or group exists before installation; this test needs a clean host"
fi

# ---------------------------------------------------------------------------
echo "== 1. Fresh install, then purge"
# ---------------------------------------------------------------------------

install_package
check "the install issued a certificate pair from the CA" \
    verifies "${certs_dir}/indexer.pem" "${ca_dir}/root-ca.pem"

purge_package
echo "Checking what the purge left behind:"
check_purged

for d in "${data_dir}" "${config_dir}"; do
    if [ -e "${d}" ]; then
        fail "${d} still exists:"
        find "${d}" | sed 's/^/        /'
    else
        ok "${d} is removed"
    fi
done
check "no 'not empty' warning for ${data_dir}" \
    not output_has "directory '${data_dir}' not empty so not removed"
check "the CA is removed" [ ! -e "${ca_dir}/root-ca.pem" ]

left=$(orphans "${default_dirs[@]}")
check "no file is left with an orphaned owner" [ -z "${left}" ]
check "the purge says it leaves custom paths alone" output_has "${note}"

# ---------------------------------------------------------------------------
echo "== 2. A used node, then purge"
# ---------------------------------------------------------------------------

install_package

# What a node that ran leaves behind, owned by the service account, with the
# permissive modes an unset UMask gives.
mkdir -p "${data_dir}/nodes/0/indices/index-uuid" "${repo_dir}/indices"
echo "segment" > "${data_dir}/nodes/0/indices/index-uuid/segment"
echo "log line" > "${log_dir}/${name}.log"
echo "keystore" > "${config_dir}/opensearch.keystore"
echo "snapshot" > "${repo_dir}/indices/snapshot"
chown -R "${name}:${name}" "${data_dir}/nodes" "${log_dir}" "${repo_dir}" "${config_dir}/opensearch.keystore"
chmod 755 "${data_dir}/nodes" "${data_dir}/nodes/0" "${data_dir}/nodes/0/indices" "${data_dir}/nodes/0/indices/index-uuid"
chmod 644 "${data_dir}/nodes/0/indices/index-uuid/segment" "${log_dir}/${name}.log" "${repo_dir}/indices/snapshot"
chmod 660 "${config_dir}/opensearch.keystore"
printf '\npath.repo: ["%s"]\n' "${repo_dir}" >> "${config_dir}/opensearch.yml"

# A link the service account could have planted, aimed at a file it does not
# own. The purge must change the link, never its target.
echo "canary" > "${canary}"
chmod 644 "${canary}"
ln -s "${canary}" "${data_dir}/nodes/trap"
chown -h "${name}:${name}" "${data_dir}/nodes/trap"

listing > /tmp/listing.installed
repo_before=$(find -P "${repo_dir}" -printf '%p %U:%G %m\n' | sort)

purge_package
echo "Checking what the purge left behind:"
check_purged

check "index data is kept" [ -f "${data_dir}/nodes/0/indices/index-uuid/segment" ]
check "the keystore is kept" [ -f "${config_dir}/opensearch.keystore" ]

left=$(orphans "${default_dirs[@]}")
if [ -z "${left}" ]; then
    ok "no file is left with an orphaned owner in the default directories"
else
    fail "files are left with an orphaned owner in the default directories:"
    printf '%s\n' "${left}" | head -10 | sed 's/^/        /'
fi

not_root=$(for d in "${default_dirs[@]}"; do
    if [ -e "${d}" ]; then find -P "${d}" \( ! -user root -o ! -group root \) 2>/dev/null; fi
done)
check "everything kept in the default directories belongs to root:root" [ -z "${not_root}" ]

open_dirs=$(for d in "${default_dirs[@]}"; do
    if [ -d "${d}" ] && [ -n "$(find "${d}" -prune -perm /077)" ]; then echo "${d}"; fi
done)
check "each default directory left is closed to everyone but root" [ -z "${open_dirs}" ]

# The files inside keep their modes: only the directories above changed.
changed=$(join -1 3 -2 3 -o 0,1.1,2.1 <(sort -k3 /tmp/listing.installed) <(listing) \
    | awk '$2 != $3' | grep -vxE "($(IFS='|'; echo "${default_dirs[*]}")) [0-7]+ [0-7]+")
if [ -z "${changed}" ]; then
    ok "every file kept has the mode it had before the purge"
else
    fail "files kept changed mode (path, before, after):"
    printf '%s\n' "${changed}" | head -10 | sed 's/^/        /'
fi

for f in indexer.pem indexer-key.pem admin.pem admin-key.pem root-ca.pem; do
    check "certs/${f}, issued from the removed CA, is removed" [ ! -e "${certs_dir}/${f}" ]
done
check "the symlink's target is untouched" \
    [ "$(stat -c '%U:%G %a' "${canary}")" = "root:root 644" ]
check "the custom path.repo is left exactly as it was" \
    [ "$(find -P "${repo_dir}" -printf '%p %U:%G %m\n' | sort)" = "${repo_before}" ]
check "the purge says it leaves custom paths alone" output_has "${note}"

# ---------------------------------------------------------------------------
echo "== 3. Reinstall"
# ---------------------------------------------------------------------------

install_package
echo "Checking what the reinstall took back:"

# The planted runtime files, and the directories that hold them, have to come
# back exactly as they were. Files the reinstall writes itself are compared too.
differs=$(join -1 3 -2 3 -o 0,1.1,1.2,2.1,2.2 <(sort -k3 /tmp/listing.installed) <(listing) \
    | awk '$2 != $4 || $3 != $5')
if [ -z "${differs}" ]; then
    ok "everything kept has the owner and mode it had before the purge"
else
    fail "files differ from before the purge (path, mode, owner before, mode, owner after):"
    printf '%s\n' "${differs}" | head -10 | sed 's/^/        /'
fi

check "the node's certificate chains to its root-ca.pem" \
    verifies "${certs_dir}/indexer.pem" "${certs_dir}/root-ca.pem"
check "the node's certificate chains to the CA in ${ca_dir}" \
    verifies "${certs_dir}/indexer.pem" "${ca_dir}/root-ca.pem"
check "the resolution completed" [ -f "${marker}" ]

# ---------------------------------------------------------------------------
echo "== 4. A default directory the purge cannot hand over, then purge"
# ---------------------------------------------------------------------------

if mount --bind "${log_dir}" "${log_dir}" 2>/dev/null \
        && mount -o remount,ro,bind "${log_dir}" 2>/dev/null; then
    purge_package
    echo "Checking what the purge left behind:"
    check "package purged cleanly" [ "${purge_rc}" -eq 0 ]
    check "the ${name} user is still removed" not user_exists
    check "the ${name} group is still removed" not group_exists
    check "the purge names ${log_dir}" \
        output_has "Some files under ${log_dir} could not be handed over to root"
    check "the purge does not claim to have kept ${log_dir} for root" \
        not output_has "Kept ${log_dir}, now owned by root"
    check "the other default directories are still handed over to root" \
        owned_by root:root "${data_dir}/nodes/0/indices/index-uuid/segment"

    umount "${log_dir}"
else
    echo "  skip: this host cannot mount ${log_dir} read-only"
    purge_package
fi

# ---------------------------------------------------------------------------
echo "== 5. A certificate pair the CA did not issue"
# ---------------------------------------------------------------------------

install_package
external_pki /tmp/external-pki
for n in indexer admin; do
    install -m 0400 -o "${name}" -g "${name}" "/tmp/external-pki/${n}.pem" "${certs_dir}/${n}.pem"
    install -m 0400 -o "${name}" -g "${name}" "/tmp/external-pki/${n}-key.pem" "${certs_dir}/${n}-key.pem"
done

echo "Checking that the resolver refuses it while ${ca_dir} holds another CA:"
rm -f "${marker}"
out=$("${resolver}" --prestart 2>&1); rc=$?
check "--prestart refuses the pair" [ "${rc}" -ne 0 ]
check "it says the pair was not issued by the CA" \
    grep -qF "was not issued by ${ca_dir}/root-ca.pem" <<< "${out}"
check "no state file while the pair is refused" [ ! -e "${marker}" ]

purge_package
echo "Checking what the purge left behind:"
check_purged
check "the operator's pair is kept" \
    bash -c "[ -f '${certs_dir}/indexer.pem' ] && [ -f '${certs_dir}/indexer-key.pem' ]"
check "the copy of the removed CA is removed" [ ! -e "${certs_dir}/root-ca.pem" ]
check "the operator's pair now belongs to root" owned_by root:root "${certs_dir}/indexer.pem"

install_package
echo "Checking the reinstall over a pair with nothing to verify it against:"
check "it says there is no CA certificate to verify the pair" \
    grep -qF "no CA certificate to verify it" <<< "${install_out}"
check "no CA is minted" [ ! -e "${ca_dir}/root-ca.pem" ]
check "no state file while the pair is unresolved" [ ! -e "${marker}" ]

echo "Checking that staging the CA that issued it resolves:"
install -m 0400 -o "${name}" -g "${name}" /tmp/external-pki/root-ca.pem "${certs_dir}/root-ca.pem"
"${resolver}" --prestart > /tmp/prestart.log 2>&1; rc=$?
check "--prestart resolves" [ "${rc}" -eq 0 ]
check "the state file is written" [ -f "${marker}" ]
check "the operator's pair is used, not replaced" \
    cmp -s /tmp/external-pki/indexer.pem "${certs_dir}/indexer.pem"

# ---------------------------------------------------------------------------

rm -f "${canary}"

if [ "${failed}" -gt 0 ]; then
    echo "ERROR: ${failed} check(s) failed" >&2
    exit 1
fi

echo "OK: purge hands the default directories over to root, takes back the certificates it issued, and a reinstall comes back as it was"
