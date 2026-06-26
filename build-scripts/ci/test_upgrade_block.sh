#!/bin/bash
# Verifies that a 5.x package correctly refuses upgrade from a 4.x installation.
# Asserts: the upgrade command fails, the block banner is present in output,
# and the installed package version is unchanged after the attempt.
#
# Required env:
#   PACKAGE_MANAGER   — "rpm" or "deb"
#   PACKAGE_NAME      — filename of the 5.x package under /artifacts/dist/
#   PREVIOUS_VERSION  — the 4.x version to install first (passed to indexer_node_install.sh)

set -euo pipefail

: "${PACKAGE_MANAGER:?PACKAGE_MANAGER is required (rpm or deb)}"
: "${PACKAGE_NAME:?PACKAGE_NAME is required}"
: "${PREVIOUS_VERSION:?PREVIOUS_VERSION is required}"

bash /build-scripts/indexer_node_install.sh "$PREVIOUS_VERSION"

case "$PACKAGE_MANAGER" in
    rpm)
        installed_before=$(rpm -q wazuh-indexer)
        echo "Installed before upgrade: $installed_before"

        set +e
        out=$(yum localinstall "/artifacts/dist/${PACKAGE_NAME}" -y 2>&1)
        rc=$?
        set -e
        ;;
    deb)
        installed_before=$(dpkg-query -W -f='${Version}' wazuh-indexer)
        echo "Installed before upgrade: wazuh-indexer=$installed_before"

        set +e
        out=$(dpkg -i --force-confnew "/artifacts/dist/${PACKAGE_NAME}" 2>&1)
        rc=$?
        set -e
        ;;
    *)
        echo "ERROR: unknown PACKAGE_MANAGER '${PACKAGE_MANAGER}' — expected 'rpm' or 'deb'" >&2
        exit 1
        ;;
esac

echo "$out"

if [ "$rc" -eq 0 ]; then
    echo "ERROR: upgrade unexpectedly succeeded" >&2; exit 1
fi
if ! echo "$out" | grep -qF "Upgrade from Wazuh indexer versions prior to 5.x is not supported"; then
    echo "ERROR: expected block banner not found in output" >&2; exit 1
fi
if ! echo "$out" | grep -qF "Detected installed version:"; then
    echo "ERROR: expected block banner not found in output" >&2; exit 1
fi

case "$PACKAGE_MANAGER" in
    rpm) installed_after=$(rpm -q wazuh-indexer) ;;
    deb) installed_after=$(dpkg-query -W -f='${Version}' wazuh-indexer) ;;
esac

if [ "$installed_before" != "$installed_after" ]; then
    echo "ERROR: package state changed (before=$installed_before after=$installed_after)" >&2; exit 1
fi

echo "OK: 5.x package correctly refused upgrade from $installed_after"
