#!/bin/bash
# Verifies that purging the package takes back what its maintainer scripts
# created outside the package manifest.
# See https://github.com/wazuh/wazuh-indexer/issues/1951
#
# Installs the package, removes it for good (`apt-get purge` / `yum remove`),
# then asserts that the wazuh-indexer user, the wazuh-indexer group and the
# data directory are gone, and that the package manager did not complain about
# the data directory being left behind. The node is never started, so the data
# directory holds nothing but what the scripts put there.
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
data_dir="/var/lib/${name}"
failed=0

ok()   { echo "  ok:   $*"; }
fail() { echo "  FAIL: $*" >&2; failed=$((failed + 1)); }

if getent passwd "${name}" > /dev/null 2>&1 || getent group "${name}" > /dev/null 2>&1; then
    echo "ERROR: ${name} user or group exists before installation; this test needs a clean host" >&2
    exit 1
fi

case "$PACKAGE_MANAGER" in
    rpm)
        yum localinstall -y "${package}"
        ;;
    deb)
        export DEBIAN_FRONTEND=noninteractive
        bash "$(dirname "$0")/install_package_dependencies.sh" "${package}"
        dpkg -i "${package}"
        ;;
    *)
        echo "ERROR: unknown PACKAGE_MANAGER '${PACKAGE_MANAGER}' — expected 'rpm' or 'deb'" >&2
        exit 1
        ;;
esac || { echo "ERROR: installation failed" >&2; exit 1; }

# Sanity: the checks below are only meaningful if installation created these.
getent passwd "${name}" > /dev/null || { echo "ERROR: installation did not create the ${name} user" >&2; exit 1; }
getent group "${name}" > /dev/null || { echo "ERROR: installation did not create the ${name} group" >&2; exit 1; }
[ -d "${data_dir}/tmp" ] || { echo "ERROR: installation did not create ${data_dir}/tmp" >&2; exit 1; }

case "$PACKAGE_MANAGER" in
    rpm)
        out=$(yum remove -y "${name}" 2>&1)
        rc=$?
        ;;
    deb)
        out=$(apt-get purge -y "${name}" 2>&1)
        rc=$?
        ;;
esac
echo "${out}"

echo "Checking what the purge left behind:"

if [ "${rc}" -eq 0 ]; then
    ok "package purged cleanly"
else
    fail "package purge exited with ${rc}"
fi

case "$PACKAGE_MANAGER" in
    rpm) rpm -q "${name}" > /dev/null 2>&1 && fail "package is still installed" ;;
    deb) dpkg-query -W -f='${db:Status-Status}' "${name}" 2>/dev/null | grep -qvx 'not-installed' \
             && fail "package is still known to dpkg (not purged)" ;;
esac

if getent passwd "${name}" > /dev/null 2>&1; then
    fail "the ${name} user still exists"
else
    ok "the ${name} user is removed"
fi

if getent group "${name}" > /dev/null 2>&1; then
    fail "the ${name} group still exists"
else
    ok "the ${name} group is removed"
fi

if [ -e "${data_dir}" ]; then
    fail "${data_dir} still exists:"
    find "${data_dir}" | sed 's/^/        /' >&2
else
    ok "${data_dir} is removed"
fi

if echo "${out}" | grep -qF "directory '${data_dir}' not empty so not removed"; then
    fail "the package manager reported ${data_dir} as not empty"
else
    ok "no 'not empty' warning for ${data_dir}"
fi

if [ "${failed}" -gt 0 ]; then
    echo "ERROR: ${failed} check(s) failed" >&2
    exit 1
fi

echo "OK: purge left no ${name} user, group or data directory behind"
