# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.10.x]
### Added

### Dependencies
- Migrate 4.10.4 to 2.19.5 [(#1403)](https://github.com/wazuh/wazuh-indexer/pull/1403)

### Changed
- Update workflow naming on 4.10.4 branch [(#1092)](https://github.com/wazuh/wazuh-indexer/pull/1092)
- Backport: Redesign the mechanism to preserve the status of the service on upgrades [(#794)](https://github.com/wazuh/wazuh-indexer/pull/794)

### Deprecated

### Removed
- Removed unused GitHub Workflows [(#967)](https://github.com/wazuh/wazuh-indexer/pull/967)

### Fixed
- Fix deadlock between engineMutex and writeLock during index close and engine reset ([#11869](https://github.com/opensearch-project/OpenSearch/issues/11869))
- Harden the circuit breaker and failure handle logic in query result consumer ([#19396](https://github.com/opensearch-project/OpenSearch/pull/19396))
- Fix case insensitive and escaped query on wildcard ([#16827](https://github.com/opensearch-project/OpenSearch/pull/16827))
- Fix array_index_out_of_bounds_exception with wildcard and aggregations ([#20842](https://github.com/opensearch-project/OpenSearch/pull/20842))
- Prevent negative fielddata stats by guarding against stale removals after shard reallocation ([#21667](https://github.com/opensearch-project/OpenSearch/pull/21667))

### Security
- Reduce risk of GITHUB_TOKEN exposure [(#972)](https://github.com/wazuh/wazuh-indexer/pull/972)

[Unreleased 4.10.x]: https://github.com/wazuh/wazuh-indexer/compare/v4.10.3...4.10.4
