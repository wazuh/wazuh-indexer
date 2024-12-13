# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.10.x]
### Added

### Dependencies

### Changed
- Upgrade third-party integrations to the latest versions ([#445](https://github.com/wazuh/wazuh-indexer/issues/445))
- Changes on the Vulnerability Detector index template ([#25485](https://github.com/wazuh/wazuh/issues/25485)) ([#382](https://github.com/wazuh/wazuh-indexer/issues/382))
- Packages refinement - Stage 1 ([#484](https://github.com/wazuh/wazuh-indexer/issues/484))

### Deprecated

### Removed

### Fixed
- Fix deadlock between engineMutex and writeLock during index close and engine reset ([#11869](https://github.com/opensearch-project/OpenSearch/issues/11869))
- Harden the circuit breaker and failure handle logic in query result consumer ([#19396](https://github.com/opensearch-project/OpenSearch/pull/19396))
- Fix case insensitive and escaped query on wildcard ([#16827](https://github.com/opensearch-project/OpenSearch/pull/16827))
- Fix array_index_out_of_bounds_exception with wildcard and aggregations ([#20842](https://github.com/opensearch-project/OpenSearch/pull/20842))
- Prevent negative fielddata stats by guarding against stale removals after shard reallocation ([#21667](https://github.com/opensearch-project/OpenSearch/pull/21667))

### Security


[Unreleased 4.10.x]: https://github.com/wazuh/wazuh-indexer/compare/b39a219a318a2b9101fa146eb195192a945963d7...4.10.0
