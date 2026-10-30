#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Checks the needrestart rule the DEB package ships. See
# https://github.com/wazuh/wazuh-indexer/issues/2048.
#
# The JVM extracts native libraries into /var/lib/wazuh-indexer/tmp and deletes
# them while they stay mapped, and needrestart restarts a service whose
# processes map deleted files. The package ships
# /etc/needrestart/conf.d/wazuh-indexer.conf so that needrestart ignores
# those mappings, and only those.
#
#   1. The rule is valid Perl (a syntax error breaks needrestart for the whole
#      host), is a root-owned 0644 conffile, and the package leaves
#      needrestart's directories at 0755.
#   2. With the indexer running and its extracted libraries mapped, needrestart
#      does not list the service, and a non-interactive apt run does not
#      restart it.
#   3. With the rule moved aside, needrestart lists the service again, so the
#      first check is not vacuous and the rule is what keeps the service out.
#
#   PACKAGE=/artifacts/dist/wazuh-indexer_5.0.0-0_amd64.deb test_needrestart.sh
#
# Requirements: root, network access to the distribution's apt mirrors and a
# throwaway systemd host (container, VM) without wazuh-indexer installed.

set -uo pipefail

: "${PACKAGE:?PACKAGE is required}"

name="wazuh-indexer"
rule="/etc/needrestart/conf.d/${name}.conf"
tmp_dir="/var/lib/${name}/tmp"
failed=0

export DEBIAN_FRONTEND=noninteractive

ok()   { echo "  ok:   $*"; }
fail() { echo "  FAIL: $*"; failed=$((failed + 1)); }
die()  { echo "ERROR: $*" >&2; exit 1; }

check() {
    local description="$1"; shift
    if "$@"; then ok "${description}"; else fail "${description}"; fi
}

# No grep -q after a pipe: it exits on the first match, the writer dies of
# SIGPIPE and pipefail turns the match into a failure.
java_pid()        { pgrep -u "${name}" -f org.opensearch.bootstrap.OpenSearch | head -1; }
maps_extracted()  { grep -q "${tmp_dir}/.*\.so (deleted)" "/proc/$1/maps" 2>/dev/null; }
service_flagged() { needrestart -b -r l 2>/dev/null | grep "^NEEDRESTART-SVC: ${name}.service$" > /dev/null; }
service_kept()    { ! service_flagged; }
mode_owner()      { [ "$(stat -c '%a %U:%G' "$1")" = "$2" ]; }
is_conffile()     { dpkg-query --showformat='${Conffiles}\n' -W "${name}" | grep " ${rule} " > /dev/null; }
valid_perl()      { local out; out=$(perl -c "$1" 2>&1) || { echo "${out}"; return 1; }; }

echo "Installing needrestart and ${PACKAGE}"
# NEEDRESTART_SUSPEND keeps needrestart out of the setup's own apt runs.
apt-get update -qq || die "apt-get update failed"
NEEDRESTART_SUSPEND=1 apt-get install -y -qq needrestart > /dev/null || die "cannot install needrestart"
NEEDRESTART_SUSPEND=1 bash "$(dirname "$0")/install_package_dependencies.sh" "${PACKAGE}" > /dev/null 2>&1 \
    || die "cannot install the package dependencies"
NEEDRESTART_SUSPEND=1 dpkg -i "${PACKAGE}" > /dev/null || die "cannot install ${PACKAGE}"
echo "needrestart $(dpkg-query --showformat='${Version}' -W needrestart)"

echo "The rule"
check "${rule} is valid Perl" valid_perl "${rule}"
check "${rule} is root:root 0644" mode_owner "${rule}" "644 root:root"
check "${rule} is a conffile" is_conffile
check "/etc/needrestart is 0755" mode_owner /etc/needrestart "755 root:root"
check "/etc/needrestart/conf.d is 0755" mode_owner /etc/needrestart/conf.d "755 root:root"

echo "Starting ${name}"
systemctl start "${name}" || die "cannot start ${name}"
pid=""
for _ in $(seq 1 90); do
    pid=$(java_pid)
    [ -n "${pid}" ] && maps_extracted "${pid}" && break
    sleep 2
done
[ -n "${pid}" ] && maps_extracted "${pid}" || die "the indexer did not map any deleted library under ${tmp_dir}"
grep "(deleted)" "/proc/${pid}/maps" | awk '{print "        " $6, $7}' | sort -u

echo "With the rule"
check "needrestart does not list ${name}.service" service_kept
# NEEDRESTART_MODE=a: needrestart restarts whatever it flags, as Ubuntu 24.04
# does by default.
NEEDRESTART_MODE=a apt-get install -y -qq jq > /dev/null 2>&1 || die "apt-get install jq failed"
check "a non-interactive apt run leaves the indexer running (pid ${pid})" [ "$(java_pid)" = "${pid}" ]

echo "Without the rule"
[ -f "${rule}" ] && mv "${rule}" "${rule}.off"
check "needrestart lists ${name}.service" service_flagged
[ -f "${rule}.off" ] && mv "${rule}.off" "${rule}"

systemctl stop "${name}"
NEEDRESTART_SUSPEND=1 apt-get purge -y -qq "${name}" > /dev/null 2>&1 || true

if [ "${failed}" -ne 0 ]; then
    echo "failed: ${failed}"
    exit 1
fi
echo "failed: 0"
