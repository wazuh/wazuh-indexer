#!/bin/bash

# Copyright Wazuh Indexer Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Install a package's declared runtime dependencies, without installing the
# package itself.
#
#   install_package_dependencies.sh /artifacts/dist/wazuh-indexer_5.0.0-0_amd64.deb
#
# The package tests install with `dpkg -i` on purpose: that is what exercises
# the maintainer scripts the way an operator's `dpkg -i` would, and routing them
# through apt would hide unpack-time behaviour behind dependency resolution.
# But `dpkg -i` does not resolve dependencies, and wazuh-indexer declares
# several for credential and TLS resolution, so they have to be on the host
# first.
#
# The list is read out of the package rather than hard-coded here. That is the
# whole point: `Depends` has changed once already and a copy in the workflow
# would silently rot the next time it changes.
#
# A no-op for RPM, where `yum localinstall` resolves dependencies by itself.

set -e

PACKAGE="${1:-}"

if [ -z "${PACKAGE}" ] || [ ! -f "${PACKAGE}" ]; then
    echo "Usage: $0 <package>" >&2
    exit 2
fi

case "${PACKAGE}" in
    *.deb) ;;
    *.rpm)
        echo "install_package_dependencies: RPM resolves its own dependencies; nothing to do"
        exit 0
        ;;
    *)
        echo "install_package_dependencies: unrecognised package type: ${PACKAGE}" >&2
        exit 2
        ;;
esac

# "a (>= 1.0), b | c, ${misc:Depends}" -> "a b"
#   * split on commas
#   * take the first side of an alternative
#   * drop the version constraint
#   * drop anything still carrying a substvar, which is not a real package
deps=$(dpkg-deb -f "${PACKAGE}" Depends 2>/dev/null \
    | tr ',' '\n' \
    | sed -e 's/|.*//' -e 's/(.*)//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v '\${' \
    | grep -v '^$' \
    | sort -u \
    | tr '\n' ' ')

if [ -z "${deps}" ]; then
    echo "install_package_dependencies: ${PACKAGE} declares no dependencies"
    exit 0
fi

echo "install_package_dependencies: installing ${deps}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# shellcheck disable=SC2086 -- deliberate word splitting into one package list
apt-get install -y ${deps}
