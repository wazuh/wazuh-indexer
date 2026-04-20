#!/bin/bash
# -----------------------------------------------------------------------------
#
# Description:
#   Synchronizes CTI (Cyber Threat Intelligence) configuration values from
#   the centralized cti-config.json file to the wazuh-indexer-plugins repo.
#
#   This script is the companion to the cti-config.json single source of truth.
#   It updates:
#     - PluginSettings.java (default URL, context and consumer values)
#     - TelemetryClient.java (PING_URI)
#     - configuration.md (documentation default values table)
#
# Usage:
#   ./sync_cti_config.sh --config <path-to-cti-config.json> --plugins-dir <path-to-wazuh-indexer-plugins>
#
# Arguments:
#   --config <path>         Path to cti-config.json (source of truth).
#   --plugins-dir <path>    Path to the root of the wazuh-indexer-plugins repo.
#   --help                  Show this help message and exit.
#
# Requirements:
#   - jq
#   - sed
#
# Exit Codes:
#   0   Success
#   1   Missing dependency, bad arguments, or update failure
#
# -----------------------------------------------------------------------------

set -euo pipefail

# =============================================================================
# Defaults
# =============================================================================
CTI_CONFIG=""
PLUGINS_DIR=""

# =============================================================================
# Usage
# =============================================================================
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Synchronizes CTI configuration from cti-config.json to wazuh-indexer-plugins.

Options:
  --config <path>         Path to cti-config.json (source of truth).
  --plugins-dir <path>    Root of the wazuh-indexer-plugins repository.
  --help                  Show this help message and exit.
EOF
    exit 0
}

# =============================================================================
# Argument parsing
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CTI_CONFIG="${2:?ERROR: --config requires a path}"
            shift 2
            ;;
        --plugins-dir)
            PLUGINS_DIR="${2:?ERROR: --plugins-dir requires a path}"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage
            ;;
    esac
done

# =============================================================================
# Validations
# =============================================================================
if [[ -z "${CTI_CONFIG}" || -z "${PLUGINS_DIR}" ]]; then
    echo "ERROR: Both --config and --plugins-dir are required."
    usage
fi

if [[ ! -f "${CTI_CONFIG}" ]]; then
    echo "ERROR: CTI config file not found: ${CTI_CONFIG}"
    exit 1
fi

for cmd in jq sed; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "ERROR: Required command '${cmd}' not found."
        exit 1
    fi
done

# =============================================================================
# Read values from cti-config.json
# =============================================================================
API_URL=$(jq -r '.api_url' "${CTI_CONFIG}")
RULESET_CONTEXT=$(jq -r '.consumers.ruleset.context' "${CTI_CONFIG}")
RULESET_CONSUMER=$(jq -r '.consumers.ruleset.consumer' "${CTI_CONFIG}")
IOC_CONTEXT=$(jq -r '.consumers.ioc.context' "${CTI_CONFIG}")
IOC_CONSUMER=$(jq -r '.consumers.ioc.consumer' "${CTI_CONFIG}")
CVE_CONTEXT=$(jq -r '.consumers.cve.context' "${CTI_CONFIG}")
CVE_CONSUMER=$(jq -r '.consumers.cve.consumer' "${CTI_CONFIG}")

echo "=== CTI Configuration ==="
echo "API URL:           ${API_URL}"
echo "Ruleset:           ${RULESET_CONTEXT} / ${RULESET_CONSUMER}"
echo "IoC:               ${IOC_CONTEXT} / ${IOC_CONSUMER}"
echo "CVE:               ${CVE_CONTEXT} / ${CVE_CONSUMER}"
echo ""

# =============================================================================
# File paths
# =============================================================================
PLUGIN_SETTINGS="${PLUGINS_DIR}/plugins/content-manager/src/main/java/com/wazuh/contentmanager/settings/PluginSettings.java"
TELEMETRY_CLIENT="${PLUGINS_DIR}/plugins/content-manager/src/main/java/com/wazuh/contentmanager/cti/console/client/TelemetryClient.java"
CONFIG_DOC="${PLUGINS_DIR}/docs/ref/modules/content-manager/configuration.md"

changed=0

# =============================================================================
# Update PluginSettings.java
# =============================================================================
update_plugin_settings() {
    local file="${PLUGIN_SETTINGS}"
    if [[ ! -f "${file}" ]]; then
        echo "WARNING: PluginSettings.java not found at ${file}, skipping."
        return
    fi

    echo "--- Updating PluginSettings.java ---"

    # CTI URL
    sed -i "s|public static final String CTI_URL = \".*\";|public static final String CTI_URL = \"${API_URL}\";|" "${file}"

    # Content (Ruleset)
    sed -i "s|private static final String DEFAULT_CONTENT_CONTEXT = \".*\";|private static final String DEFAULT_CONTENT_CONTEXT = \"${RULESET_CONTEXT}\";|" "${file}"
    sed -i "s|private static final String DEFAULT_CONTENT_CONSUMER = \".*\";|private static final String DEFAULT_CONTENT_CONSUMER = \"${RULESET_CONSUMER}\";|" "${file}"

    # IoC
    sed -i "s|private static final String DEFAULT_IOC_CONTEXT = \".*\";|private static final String DEFAULT_IOC_CONTEXT = \"${IOC_CONTEXT}\";|" "${file}"
    sed -i "s|private static final String DEFAULT_IOC_CONSUMER = \".*\";|private static final String DEFAULT_IOC_CONSUMER = \"${IOC_CONSUMER}\";|" "${file}"

    # CVE
    sed -i "s|private static final String DEFAULT_CVE_CONTEXT = \".*\";|private static final String DEFAULT_CVE_CONTEXT = \"${CVE_CONTEXT}\";|" "${file}"
    sed -i "s|private static final String DEFAULT_CVE_CONSUMER = \".*\";|private static final String DEFAULT_CVE_CONSUMER = \"${CVE_CONSUMER}\";|" "${file}"

    echo "  PluginSettings.java updated."
    changed=1
}

# =============================================================================
# Update TelemetryClient.java
# =============================================================================
update_telemetry_client() {
    local file="${TELEMETRY_CLIENT}"
    if [[ ! -f "${file}" ]]; then
        echo "WARNING: TelemetryClient.java not found at ${file}, skipping."
        return
    fi

    echo "--- Updating TelemetryClient.java ---"

    sed -i "s|private static final String PING_URI = \".*\";|private static final String PING_URI = \"${API_URL}/ping\";|" "${file}"

    echo "  TelemetryClient.java updated."
    changed=1
}

# =============================================================================
# Update configuration.md
# =============================================================================
update_config_doc() {
    local file="${CONFIG_DOC}"
    if [[ ! -f "${file}" ]]; then
        echo "WARNING: configuration.md not found at ${file}, skipping."
        return
    fi

    echo "--- Updating configuration.md ---"

    # CTI API URL default (reemplazo robusto usando ~ como delimitador)
    sed -i "s~^\(| \`plugins.content_manager.cti.api\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*Base URL for the Wazuh CTI API.*\)$~\1${API_URL}\2~" "${file}"

    # Context/consumer defaults en la tabla markdown
    sed -i "s~^\(| \`plugins.content_manager.catalog.content.context\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*CTI catalog content context identifier.*\)$~\1${RULESET_CONTEXT}\2~" "${file}"
    sed -i "s~^\(| \`plugins.content_manager.catalog.content.consumer\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*CTI catalog content consumer identifier.*\)$~\1${RULESET_CONSUMER}\2~" "${file}"
    sed -i "s~^\(| \`plugins.content_manager.ioc.content.context\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*IoC content context identifier.*\)$~\1${IOC_CONTEXT}\2~" "${file}"
    sed -i "s~^\(| \`plugins.content_manager.ioc.content.consumer\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*IoC content consumer identifier.*\)$~\1${IOC_CONSUMER}\2~" "${file}"
    sed -i "s~^\(| \`plugins.content_manager.cve.content.context\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*CVE content context identifier.*\)$~\1${CVE_CONTEXT}\2~" "${file}"
    sed -i "s~^\(| \`plugins.content_manager.cve.content.consumer\`[[:space:]]*| String  | \`\)[^\`]*\(\`.*CVE content consumer identifier.*\)$~\1${CVE_CONSUMER}\2~" "${file}"

    echo "  configuration.md updated."
    changed=1
}

# =============================================================================
# Main
# =============================================================================
update_plugin_settings
update_telemetry_client
update_config_doc

if [[ "${changed}" -eq 1 ]]; then
    echo ""
    echo "=== Sync complete. Files updated successfully. ==="
else
    echo ""
    echo "=== No files were updated. ==="
fi