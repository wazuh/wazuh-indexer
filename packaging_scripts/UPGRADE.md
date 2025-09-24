# Wazuh Indexer packages upgrade

## Automatic configuration merge on upgrade

Since 4.14.0, the Wazuh Indexer packages automatically merge any new default settings into the existing configuration files on upgrade (currently, only applies to the `opensearch.yml`). This merging process is non-destructive and preserves any user-defined settings, it only appends missing settings.
The implementation is part of the post-installation scripts of both RPM and DEB packages, and is handled by a helper script included in the package, `/usr/share/wazuh-indexer/bin/merge_config.sh`. It detects new default settings files left by the package manager (e.g., `opensearch.yml.rpmnew` or `opensearch.yml.dpkg-dist`) and merges them into the active configuration file. Once completed, the temporary new file is removed.

Commented-out lines (starting with `#`) are ignored, so they do not count as "existing settings". Nested blocks are supported, appending only missing nested fields. Lists are merged by appending only missing values, preserving the destination order. The script is idempotent: running it multiple times does not duplicate keys.

Configuration file ownership is preserved, set to `wazuh-indexer:wazuh-indexer` with mode `0640`.

### Testing

Automatic tests were developed to verify the merging behavior, covering various scenarios including nested blocks and lists. These tests are containerized and can be run without any local dependencies. These can be found in the `wazuh-indexer/packaging_scripts/tests` directory. Refer to the `README.md` in that directory for instructions on how to run them.
