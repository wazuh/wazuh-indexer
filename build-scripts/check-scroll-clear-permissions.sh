#!/bin/bash

set -euo pipefail

# Any role granted a cluster permission that can open a scroll context must
# also be granted indices:data/read/scroll/clear, or it can fill the shared
# search.max_open_scroll_context pool without being able to free it.
#
# cluster_composite_ops and cluster_composite_ops_ro both include
# indices:data/read/scroll (see opensearch-project/security
# src/main/resources/static_config/static_action_groups.yml); neither
# includes scroll/clear.

ROLES_FILE="distribution/src/config/security/roles.wazuh.yml"
SCROLL_CLEAR_ACTION="indices:data/read/scroll/clear"
SCROLL_OPEN_GRANTS=("cluster_composite_ops" "cluster_composite_ops_ro" "indices:data/read/scroll")

fail=0

for role in $(yq '. | keys | .[]' "$ROLES_FILE" -o=json | tr -d '"'); do
    perms="$(yq ".${role}.cluster_permissions[]" "$ROLES_FILE" 2>/dev/null || true)"

    can_open=false
    for grant in "${SCROLL_OPEN_GRANTS[@]}"; do
        if grep -qxF "$grant" <<<"$perms"; then
            can_open=true
            break
        fi
    done

    if $can_open && ! grep -qxF "$SCROLL_CLEAR_ACTION" <<<"$perms"; then
        echo "FAIL: role '${role}' can open a scroll but is not granted ${SCROLL_CLEAR_ACTION}"
        fail=1
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "OK: every role that can open a scroll can also clear it"
fi

exit "$fail"
