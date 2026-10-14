#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Checks that the scripts a package ships and runs call no host tool the package
# does not declare. See https://github.com/wazuh/wazuh-indexer/issues/2020.
#
# The package declares openssl, ip (iproute) and the account tools, and relies on
# shell builtins, coreutils, getent (glibc), systemctl and restorecon for
# everything else. Every other command is a dependency the package would be
# using without saying so, which works only while the host happens to carry it.
#
# The scan is static. Each non-comment line of a script is split into simple
# commands (on pipes, lists, subshells and command substitutions); the first
# word of each, after any variable assignment and the usual prefixes (nohup,
# exec, env, !), is the command it runs. A command outside the closure fails
# the check. The DEB maintainer scripts may use grep, sed and find, which are
# Essential on Debian; the RPM scriptlets and the shipped scripts may not.
#
# The two tools built from the installation assistant, wazuh-certs-tool.sh and
# wazuh-passwords-tool.sh, are checked only for what the assembly step removes
# from them (runuser, ps, cmp, flock); their own use of awk, sed and grep
# belongs to that repository.
#
#   PACKAGE=/path/to/wazuh-indexer_5.0.0-0_amd64.deb bash test_host_tools.sh
#
# Requirements: dpkg-deb for a DEB, rpm, rpm2cpio and cpio for an RPM. Exit
# status is the number of scripts that failed.

set -u

PACKAGE="${PACKAGE:-}"
if [ -z "${PACKAGE}" ] || [ ! -f "${PACKAGE}" ]; then
    echo "FATAL: set PACKAGE to the .deb or .rpm to test" >&2
    exit 125
fi

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

# Tools outside the closure. Builtins, coreutils, openssl, ip, getent, systemctl, restorecon,
# the account tools, and the service-manager tools the scripts probe with `command -v` first
# (service, chkconfig, update-rc.d, systemd-tmpfiles, sysctl) are not listed.
STRICT="awk gawk mawk sed grep egrep fgrep find xargs hostname runuser su sudo ps pgrep pkill cmp diff flock setsid perl python python3 curl wget nc netstat ss lsof"
# What the DEB maintainer scripts may use on top of the closure: Essential on Debian.
DEB_ALLOWED="grep sed find"
# What the assembly step removes from the assistant's tools.
TOOLS_ONLY="runuser ps cmp flock"

cat > "${work}/scan.awk" <<'AWK'
/^[[:space:]]*#/ { next }
{
    line = $0
    sub(/[[:space:]]#.*$/, "", line)
    gsub(/\$\(/, "(", line)
    n = split(line, seg, /\|\||&&|\||;|\(|\)|`|\{|\}/)
    for (i = 1; i <= n; i++) {
        s = seg[i]
        sub(/^[[:space:]]+/, "", s)
        while (s != "") {
            if (match(s, /^(!|then|do|else|elif|if|while|until|nohup|exec|env|time)([[:space:]]+|$)/)) {
                s = substr(s, RLENGTH + 1)
                continue
            }
            if (match(s, /^[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'[^']*'|[^[:space:]]*)[[:space:]]*/)) {
                s = substr(s, RLENGTH + 1)
                continue
            }
            break
        }
        if (s == "") continue
        w = s
        sub(/[[:space:]].*$/, "", w)
        sub(/.*\//, "", w)
        if (index(forbidden, " " w " ") > 0) printf "%d: %s\n", NR, w
    }
}
AWK

failed=0

# scan <label> <file> <forbidden tools...>
scan() {
    local label="$1" file="$2"; shift 2
    local hits
    hits=$(awk -v forbidden=" $* " -f "${work}/scan.awk" "${file}")
    if [ -n "${hits}" ]; then
        echo "  FAIL: ${label} runs host tools outside the declared closure:"
        printf '%s\n' "${hits}" | sort -t: -k1,1n -u | head -20 | sed 's/^/        line /'
        failed=$((failed + 1))
    else
        echo "  ok:   ${label}"
    fi
}

deb_strict=$(for t in ${STRICT}; do case " ${DEB_ALLOWED} " in *" ${t} "*) ;; *) printf '%s ' "${t}" ;; esac; done)

case "${PACKAGE}" in
    *.deb)
        mkdir -p "${work}/control" "${work}/data"
        dpkg-deb -e "${PACKAGE}" "${work}/control"
        dpkg-deb -x "${PACKAGE}" "${work}/data"
        for script in preinst postinst prerm postrm; do
            [ -f "${work}/control/${script}" ] || continue
            scan "DEB ${script}" "${work}/control/${script}" ${deb_strict}
        done
        ;;
    *.rpm)
        mkdir -p "${work}/data"
        (cd "${work}/data" && rpm2cpio "${PACKAGE}" | cpio -idm --quiet)
        rpm -qp --scripts "${PACKAGE}" > "${work}/scriptlets" 2>/dev/null
        # Split the scriptlets on their headers ("preinstall scriptlet (using /bin/sh):").
        awk -v dir="${work}" '
            /^[a-z]+ scriptlet \(using / { name = $1; next }
            name != "" { print > (dir "/" name) }
        ' "${work}/scriptlets"
        for script in preinstall postinstall preuninstall postuninstall posttrans; do
            [ -f "${work}/${script}" ] || continue
            scan "RPM ${script}" "${work}/${script}" ${STRICT}
        done
        ;;
    *)
        echo "FATAL: unrecognised package type: ${PACKAGE}" >&2
        exit 125
        ;;
esac

root="${work}/data"
for rel in usr/share/wazuh-indexer/bin/resolve-credentials.sh \
           usr/share/wazuh-indexer/lib/wazuh-indexer-credentials.sh \
           usr/share/wazuh-indexer/bin/indexer-security-init.sh \
           usr/share/wazuh-indexer/bin/opensearch \
           etc/init.d/wazuh-indexer \
           usr/lib/systemd/system/wazuh-indexer.service; do
    if [ -f "${root}/${rel}" ]; then
        scan "${rel}" "${root}/${rel}" ${STRICT}
    else
        echo "  FAIL: ${rel} is not in the package"
        failed=$((failed + 1))
    fi
done
for rel in usr/share/wazuh-indexer/tools/wazuh-certs-tool.sh \
           usr/share/wazuh-indexer/tools/wazuh-passwords-tool.sh; do
    if [ -f "${root}/${rel}" ]; then
        scan "${rel} (assembly-time removals only)" "${root}/${rel}" ${TOOLS_ONLY}
    else
        echo "  skip: ${rel} is not in the package"
    fi
done

if [ -e "${root}/usr/share/wazuh-indexer/lib/wazuh-credentials.sh" ]; then
    echo "  FAIL: the shared helper of the previous model is still shipped"
    failed=$((failed + 1))
else
    echo "  ok:   lib/wazuh-credentials.sh is not shipped"
fi
if ls -d "${root}"/usr/share/wazuh-indexer/test* > /dev/null 2>&1; then
    echo "  FAIL: a package test suite is shipped under the product tree"
    failed=$((failed + 1))
else
    echo "  ok:   no test suite under the product tree"
fi

echo "failed: ${failed}"
[ "${failed}" -gt 125 ] && exit 125
exit "${failed}"
