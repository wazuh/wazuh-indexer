## Post-install config merging

As part of the issue [(#1146)](https://github.com/wazuh/wazuh-indexer/issues/1146), the packages include a post-install step that checks for a new packaged `opensearch.yml` left by the package manager on upgrade (for example, `/etc/wazuh-indexer/opensearch.yml.rpmnew` on RPM systems or `/etc/wazuh-indexer/opensearch.yml.dpkg-dist` on Debian systems). Any top-level settings present in the new file but missing in the active configuration are appended to `/etc/wazuh-indexer/opensearch.yml`, preserving existing user values. After merging, the temporary new file is removed.

Helper script: `/usr/share/wazuh-indexer/bin/merge_opensearch_yml.sh`.

Behavior details
Performs a conservative, non-destructive merge that adds only missing settings, never overwriting existing values. For example, if the package adds:

  uiSettings:
    overrides:
      "home:useNewHomePage": true

  and the user already has `uiSettings:` but not `overrides` or the nested flag, the script will add only the missing nested fields.

Notes
- Commented-out lines are ignored (they don’t count as “existing settings”).
- The script doesn’t overwrite existing values; it only adds missing ones.
- Resulting file ownership is `wazuh-indexer:wazuh-indexer` with mode `0640`.

Testing
- Containerized tests: no local deps required.
  - Build and run with Docker Compose: `./run-bats.sh`
  - This uses `tests/Dockerfile.awk` and `tests/test.yml` to run the suite in a container.