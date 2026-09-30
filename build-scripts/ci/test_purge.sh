#!/bin/bash
# Verifies that purging the package takes back what its maintainer scripts
# created, and that nothing it leaves in its own directories can be inherited by
# another account.
# See https://github.com/wazuh/wazuh-indexer/issues/1951
#
# The purge manages the package's default directories -- /etc/wazuh-indexer,
# /usr/share/wazuh-indexer, /var/lib/wazuh-indexer and /var/log/wazuh-indexer --
# and nothing else, and it always removes the wazuh-indexer user and group.
#
# Four scenarios, run one after the other on the same host:
#
#   1. Fresh install, then purge. Nothing is left: no user, no group, no data
#      directory, and no "not empty" warning from the package manager.
#   2. A node that has been used, then purge. Index data, logs, a snapshot
#      repository at a custom path.repo and a planted symlink stand in for a
#      node that ran. Every file the account owned in the default directories is
#      handed over to root with group and other access stripped, so none is left
#      with an orphaned owner there. The custom snapshot repository is not
#      touched, the symlink's target is not touched, and the purge says that
#      directories set elsewhere in opensearch.yml are left as they are.
#   3. Reinstall. The files kept in the default directories belong to
#      wazuh-indexer again.
#   4. A default directory the purge cannot hand over (a read-only mount), then
#      purge. The user and group are still removed, the purge names that
#      directory, and it does not claim to have kept it for root.
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
data_dir="/var/lib/${name}"
log_dir="/var/log/${name}"
product_dir="/usr/share/${name}"
default_dirs=("${config_dir}" "${product_dir}" "${data_dir}" "${log_dir}")
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

# Prints every file under the given paths that still carries an owner or group
# with no account behind it.
orphans() {
    local existing=()
    for p in "$@"; do [ -e "${p}" ] && existing+=("${p}"); done
    [ ${#existing[@]} -gt 0 ] || return 0
    find -P "${existing[@]}" \( -nouser -o -nogroup \) 2>/dev/null
}

install_package() {
    case "$PACKAGE_MANAGER" in
        rpm)
            yum localinstall -y "${package}"
            ;;
        deb)
            export DEBIAN_FRONTEND=noninteractive
            if [ -z "${deps_installed:-}" ]; then
                bash "$(dirname "$0")/install_package_dependencies.sh" "${package}" || return 1
                deps_installed=1
            fi
            dpkg -i "${package}"
            ;;
    esac || die "installation failed"

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
    echo "${purge_out}"
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
purge_package
echo "Checking what the purge left behind:"
check_purged

if [ -e "${data_dir}" ]; then
    fail "${data_dir} still exists:"
    find "${data_dir}" | sed 's/^/        /'
else
    ok "${data_dir} is removed"
fi
check "no 'not empty' warning for ${data_dir}" \
    not output_has "directory '${data_dir}' not empty so not removed"

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
echo "snapshot" > "${repo_dir}/indices/snapshot"
chown -R "${name}:${name}" "${data_dir}/nodes" "${log_dir}" "${repo_dir}"
chmod 644 "${data_dir}/nodes/0/indices/index-uuid/segment" "${log_dir}/${name}.log" "${repo_dir}/indices/snapshot"
printf '\npath.repo: ["%s"]\n' "${repo_dir}" >> "${config_dir}/opensearch.yml"

# A link the service account could have planted, aimed at a file it does not
# own. The purge must change the link, never its target.
echo "canary" > "${canary}"
chmod 644 "${canary}"
ln -s "${canary}" "${data_dir}/nodes/trap"
chown -h "${name}:${name}" "${data_dir}/nodes/trap"

# What the service account owns in the default directories right before the
# purge: these, and only these, are what the purge must hand over to root. The
# custom snapshot repository is recorded as it is, to prove it is left alone.
mapfile -t user_owned < <(find -P "${default_dirs[@]}" -user "${name}" ! -type l 2>/dev/null)
mapfile -t group_owned < <(find -P "${default_dirs[@]}" -group "${name}" ! -user "${name}" ! -type l 2>/dev/null)
repo_before=$(find -P "${repo_dir}" -printf '%p %U:%G %m\n' | sort)

purge_package
echo "Checking what the purge left behind:"
check_purged

check "index data is kept" [ -f "${data_dir}/nodes/0/indices/index-uuid/segment" ]

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

# Group and other access is stripped from what the account owned; group access
# from what only its group owned.
open=$(
    for f in "${user_owned[@]}"; do [ -n "$(find "${f}" -prune -perm /077)" ] && echo "${f}"; done
    for f in "${group_owned[@]}"; do [ -n "$(find "${f}" -prune -perm /070)" ] && echo "${f}"; done
)
check "the account owned something to hand over" [ ${#user_owned[@]} -gt 0 ]
if [ -z "${open}" ]; then
    ok "nothing the account owned is readable by group or others"
else
    fail "files the account owned are still readable by group or others:"
    printf '%s\n' "${open}" | head -10 | sed 's/^/        /'
fi

check "the node's private key is kept, owned by root" \
    owned_by root:root "${config_dir}/certs/indexer-key.pem"
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

for kept in "${data_dir}/nodes/0/indices/index-uuid/segment" \
            "${log_dir}/${name}.log" \
            "${config_dir}/certs/indexer-key.pem"; do
    check "${kept} belongs to ${name} again" owned_by "${name}:${name}" "${kept}"
done

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
fi

# ---------------------------------------------------------------------------

rm -f "${canary}"

if [ "${failed}" -gt 0 ]; then
    echo "ERROR: ${failed} check(s) failed" >&2
    exit 1
fi

echo "OK: purge hands the default directories over to root, leaves everything else alone, and always removes the account"
