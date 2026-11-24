#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Checks how a package ships the configuration directory of the setup plugin.
# See https://github.com/wazuh/wazuh-indexer-plugins/issues/1810.
#
# The plugin brings /etc/wazuh-indexer/wazuh-indexer-setup: setup.yml, one
# <policy-id>.json per default ISM policy, and a README. An operator edits
# setup.yml and the policy files, so an upgrade must keep an edited one. That
# is the package manager's doing, and it depends on how the package lists the
# files: %config(noreplace) in an RPM, conffiles in a DEB. A file listed any
# other way is replaced by every upgrade, without a warning.
#
# The check is static: it reads the package and does not install it. A package
# built with a setup plugin that has no configuration directory has nothing to
# check, and passes. A package that has the directory is checked in full, so a
# file of it that is renamed, or a package that cannot be read, fails.
#
#   PACKAGE=/path/to/wazuh-indexer_5.0.0-0_amd64.deb bash test_setup_config.sh
#
# Requirements: dpkg-deb for a DEB, rpm for an RPM. Exit status is the number of
# failed checks.

set -u

PACKAGE="${PACKAGE:-}"
if [ -z "${PACKAGE}" ] || [ ! -f "${PACKAGE}" ]; then
    echo "FATAL: set PACKAGE to the .deb or .rpm to test" >&2
    exit 125
fi

CONFIG_DIR=/etc/wazuh-indexer/wazuh-indexer-setup
MODE=-rw-r-----

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

fatal() {
    echo "FATAL: $*" >&2
    exit 125
}

# files.txt: one line per file of the directory, "<path> <mode> <config>", where <config> is yes
# when the package manager keeps an edited copy of the file on upgrade. A package that cannot be
# read stops the check, instead of reading as a package without the directory.
case "${PACKAGE}" in
    *.rpm)
        command -v rpm > /dev/null 2>&1 || fatal "rpm is needed to read ${PACKAGE##*/}"
        # FILEFLAGS: c is %config, n is noreplace.
        rpm -qp --queryformat '[%{FILENAMES} %{FILEMODES:perms} %{FILEFLAGS:fflags}\n]' "${PACKAGE}" \
            > "${work}/listing.txt" || fatal "rpm cannot read ${PACKAGE##*/}"
        [ -s "${work}/listing.txt" ] || fatal "rpm read no file from ${PACKAGE##*/}"
        while read -r path mode flags; do
            case "${path}" in "${CONFIG_DIR}"/*) ;; *) continue ;; esac
            case "${mode}" in d*) continue ;; esac
            config=no
            case "${flags}" in *c*n* | *n*c*) config=yes ;; esac
            echo "${path} ${mode} ${config}"
        done < "${work}/listing.txt" > "${work}/files.txt"
        ;;
    *.deb)
        command -v dpkg-deb > /dev/null 2>&1 || fatal "dpkg-deb is needed to read ${PACKAGE##*/}"
        dpkg-deb --ctrl-tarfile "${PACKAGE}" > "${work}/control.tar" ||
            fatal "dpkg-deb cannot read the control files of ${PACKAGE##*/}"
        # A package with no file under /etc has no conffiles.
        : > "${work}/conffiles.txt"
        if tar -tf "${work}/control.tar" | grep -qx './conffiles'; then
            tar -xOf "${work}/control.tar" ./conffiles > "${work}/conffiles.txt" ||
                fatal "cannot read the conffiles of ${PACKAGE##*/}"
        fi
        dpkg-deb -c "${PACKAGE}" > "${work}/listing.txt" ||
            fatal "dpkg-deb cannot read the files of ${PACKAGE##*/}"
        [ -s "${work}/listing.txt" ] || fatal "dpkg-deb read no file from ${PACKAGE##*/}"
        while read -r mode _owner _size _date _time path _rest; do
            path=${path#.}
            case "${path}" in "${CONFIG_DIR}"/*) ;; *) continue ;; esac
            case "${mode}" in d*) continue ;; esac
            config=no
            grep -qxF "${path}" "${work}/conffiles.txt" && config=yes
            echo "${path} ${mode} ${config}"
        done < "${work}/listing.txt" > "${work}/files.txt"
        ;;
    *)
        fatal "${PACKAGE} is neither a .deb nor a .rpm"
        ;;
esac

if [ ! -s "${work}/files.txt" ]; then
    echo "SKIP: ${PACKAGE##*/} has no file in ${CONFIG_DIR}: its setup plugin ships no configuration directory"
    exit 0
fi

failures=0
pass() { echo "PASS: $*"; }
fail() {
    echo "FAIL: $*"
    failures=$((failures + 1))
}

policies=0
readme=no
while read -r path mode config; do
    name=${path#"${CONFIG_DIR}"/}
    case "${name}" in
        setup.yml | *.json)
            case "${name}" in *.json) policies=$((policies + 1)) ;; esac
            if [ "${config}" = yes ]; then
                pass "${name} is kept on upgrade when edited"
            else
                fail "${name} is not listed as configuration: an upgrade replaces an edited copy"
            fi
            ;;
        README.md)
            readme=yes
            ;;
        *)
            fail "${name} is not a file the setup plugin is known to ship"
            ;;
    esac
    if [ "${mode}" = "${MODE}" ]; then
        pass "${name} has mode ${MODE}"
    else
        fail "${name} has mode ${mode}, expected ${MODE}"
    fi
done < "${work}/files.txt"

if grep -q "^${CONFIG_DIR}/setup.yml " "${work}/files.txt"; then
    pass "setup.yml shipped"
else
    fail "setup.yml is missing"
fi
if [ "${policies}" -gt 0 ]; then
    pass "${policies} ISM policy file(s) shipped"
else
    fail "no ISM policy file shipped next to setup.yml"
fi
if [ "${readme}" = yes ]; then
    pass "README.md shipped"
else
    fail "README.md is missing"
fi

echo "${failures} failed check(s)"
exit "${failures}"
