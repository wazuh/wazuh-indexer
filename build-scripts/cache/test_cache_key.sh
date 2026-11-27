#!/bin/bash

# Checks the cache key rules of cache-key.sh on a throwaway clone of this repository:
# each case changes one file and asserts whether the core key moves. The plugin cases
# check that a key moves with its own inputs and with those of its dependencies only.
#
# Usage: bash build-scripts/cache/test_cache_key.sh

set -euo pipefail

CACHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${CACHE_DIR}/../.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
CLONE="${WORK}/repo"

failures=0

function pass() { echo "PASS  $1"; }
function fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

# The clone gets the working tree (tracked and untracked files, not the ignored ones) and
# commits it, so uncommitted rules and .gitignore changes are tested too. The commit
# stays in the throwaway clone.
git clone -q --shared "${REPO_ROOT}" "${CLONE}"
git -C "${CLONE}" checkout -q --detach "$(git -C "${REPO_ROOT}" rev-parse HEAD)"
(cd "${REPO_ROOT}" && git ls-files -z --cached --others --exclude-standard |
    tar --null --ignore-failed-read -T - -cf - 2>/dev/null) | tar -xf - -C "${CLONE}"
(cd "${REPO_ROOT}" && git ls-files -z --deleted) | (cd "${CLONE}" && xargs -0 -r rm -f)
git -C "${CLONE}" add -A
git -C "${CLONE}" -c user.name=test -c user.email=test@localhost -c commit.gpgsign=false \
    commit -q --allow-empty -m "working tree under test"

KEY="${CLONE}/build-scripts/cache/cache-key.sh"

function core_key() { bash "${KEY}" core -d "${1:-deb}" -a "${2:-x64}"; }

function reset_clone() {
    git -C "${CLONE}" reset -q --hard HEAD
    git -C "${CLONE}" clean -q -fd
}

BASE="$(core_key)"
# Any tracked source file of the server (used in the commands that expect_core evaluates).
# shellcheck disable=SC2034
SERVER_FILE="$(git -C "${CLONE}" ls-files 'server/src/main/java/*.java' | sed -n 1p)"

# expect_core <same|changed> <description> <command run inside the clone>
function expect_core() {
    local expected="$1" description="$2" command="$3" key
    (cd "${CLONE}" && eval "${command}")
    key="$(core_key)"
    if { [ "${expected}" = same ] && [ "${key}" = "${BASE}" ]; } ||
        { [ "${expected}" = changed ] && [ "${key}" != "${BASE}" ]; }; then
        pass "core key ${expected}: ${description}"
    else
        fail "core key not ${expected}: ${description}"
    fi
    reset_clone
}

# The key of a clean tree is the key of its commit.
if [ "$(bash "${KEY}" core -d deb -a x64 -c HEAD)" = "${BASE}" ]; then
    pass "core key of the working tree equals the key of HEAD (-c)"
else
    fail "core key of the working tree differs from the key of HEAD (-c)"
fi
[ "$(core_key rpm x64)" != "${BASE}" ] && pass "core key differs per distribution" || fail "core key ignores the distribution"
[ "$(core_key deb arm64)" != "${BASE}" ] && pass "core key differs per architecture" || fail "core key ignores the architecture"

# Inputs that do not reach the core, or that the assembly reads from the repository.
expect_core same "CHANGELOG.md" 'echo "- entry" >> CHANGELOG.md'
expect_core same "a workflow" 'echo "# c" >> .github/workflows/5_builderpackage_indexer.yml'
expect_core same "a CI test script" 'echo "# c" >> build-scripts/ci/test_purge.sh'
expect_core same "assemble.sh" 'echo "# c" >> build-scripts/assemble.sh'
expect_core same "the RPM spec" 'echo "# c" >> distribution/packages/src/rpm/wazuh-indexer.rpm.spec'
expect_core same "a DEB maintainer script" 'echo "# c" >> distribution/packages/src/deb/debian/postinst'
expect_core same "debmake_install.sh" 'echo "# c" >> distribution/packages/src/deb/debmake_install.sh'
expect_core same "the credential library" 'echo "# c" >> distribution/src/lib/wazuh-indexer-credentials.sh'
expect_core same "opensearch.prod.yml" 'echo "# c" >> distribution/src/config/opensearch.prod.yml'
expect_core same "a *.wazuh.yml security file" 'echo "# c" >> distribution/src/config/security/roles.wazuh.yml'
expect_core same "the VERSION.json stage" 'jq ".stage = \"rc9\"" VERSION.json > v && mv v VERSION.json'
expect_core same "an untracked file under tools/" 'touch tools/new-tool.sh'
expect_core same ".gitignore" 'echo "/new-ignored/" >> .gitignore'
expect_core same "builder leftovers in the repository root (HOME of the builder)" 'mkdir -p .rpmdb .m2/repository && touch .rpmdb/rpmdb.sqlite .devscripts .m2/repository/x.pom'

# Inputs of the Gradle build, or files bundled as they are.
expect_core changed "the VERSION.json version" 'jq ".version = \"5.0.9\"" VERSION.json > v && mv v VERSION.json'
expect_core changed "build.sh" 'echo "# c" >> build-scripts/build.sh'
expect_core changed "product_version.sh" 'echo "# c" >> build-scripts/product_version.sh'
expect_core changed "README.md (bundled)" 'echo "c" >> README.md'
expect_core changed "a server source file" 'echo "// c" >> "${SERVER_FILE}"'
expect_core changed "buildSrc" 'echo "// c" >> buildSrc/build.gradle'
expect_core changed "the bundled JDK version" 'sed -i "s/^bundled_jdk = .*/bundled_jdk = \"0.0.0\"/" gradle/libs.versions.toml'
expect_core changed "resolve-credentials.sh (shipped as is)" 'echo "# c" >> distribution/src/bin/resolve-credentials.sh'
expect_core changed "jvm.options (token-expanded)" 'echo "# c" >> distribution/src/config/jvm.options'
expect_core changed "the systemd unit" 'echo "# c" >> distribution/packages/src/common/systemd/wazuh-indexer.service'
expect_core changed "the needrestart rule (bundled by Gradle)" 'echo "# c" >> distribution/packages/src/deb/needrestart/wazuh-indexer.conf'
expect_core changed "a new security file that is not *.wazuh.yml" 'touch distribution/src/config/security/extra.yml'
expect_core changed "an executable bit" 'chmod +x README.md'
expect_core changed "an untracked source file" 'touch server/src/main/java/org/opensearch/NewFile.java'
expect_core changed "a deleted source file" 'git rm -q "${SERVER_FILE}"'

# Plugins: a key moves with its own inputs and the keys of its dependencies, nothing else.
REPOS=(common-utils alerting security-analytics notifications reporting plugins)
function plugin_keys() {
    local args=() repo
    for repo in "${REPOS[@]}"; do
        args+=(-p "wazuh-indexer-${repo}=${COMMITS[${repo}]}")
    done
    bash "${KEY}" plugins -v "${VERSION:-5.0.0}" -r "${REVISION:-0}" "${args[@]}"
}
declare -A COMMITS
for repo in "${REPOS[@]}"; do
    COMMITS[${repo}]="$(printf '%s' "${repo}" | sha1sum | cut -d' ' -f1)"
done
PLUGINS_BASE="$(plugin_keys)"

# expect_plugins <description> <space-separated repos whose key must change>
function expect_plugins() {
    local description="$1" expected=" $2 " now changed="" repo
    now="$(plugin_keys)"
    for repo in "${REPOS[@]}"; do
        if [ "$(grep "^wazuh-indexer-${repo} " <<<"${now}")" != "$(grep "^wazuh-indexer-${repo} " <<<"${PLUGINS_BASE}")" ]; then
            changed+="${repo} "
        fi
    done
    local want=""
    for repo in "${REPOS[@]}"; do
        [[ "${expected}" == *" ${repo} "* ]] && want+="${repo} "
    done
    if [ "${changed}" = "${want}" ]; then
        pass "plugin keys: ${description} -> ${changed:-none}"
    else
        fail "plugin keys: ${description} -> ${changed:-none}, expected ${want:-none}"
    fi
}

expect_plugins "same inputs" ""
for repo in "${REPOS[@]}"; do
    saved="${COMMITS[${repo}]}"
    COMMITS[${repo}]="$(printf '%s-changed' "${repo}" | sha1sum | cut -d' ' -f1)"
    case "${repo}" in
    common-utils) expect_plugins "common-utils commit" "common-utils alerting security-analytics notifications reporting plugins" ;;
    alerting) expect_plugins "alerting commit" "alerting security-analytics plugins" ;;
    security-analytics) expect_plugins "security-analytics commit" "security-analytics plugins" ;;
    notifications) expect_plugins "notifications commit" "notifications" ;;
    reporting) expect_plugins "reporting commit" "reporting" ;;
    plugins) expect_plugins "plugins commit" "plugins" ;;
    esac
    COMMITS[${repo}]="${saved}"
done
REVISION=1 expect_plugins "revision" "common-utils alerting security-analytics notifications reporting plugins"
VERSION=5.0.1 expect_plugins "product version" "common-utils alerting security-analytics notifications reporting plugins"

if bash "${KEY}" plugins -v 5.0.0 -r 0 -p wazuh-indexer-common-utils=main >/dev/null 2>&1; then
    fail "plugin keys accept a branch name instead of a commit SHA"
else
    pass "plugin keys refuse a branch name instead of a commit SHA"
fi

echo
if [ "${failures}" -gt 0 ]; then
    echo "${failures} check(s) failed"
    exit 1
fi
echo "All checks passed"
