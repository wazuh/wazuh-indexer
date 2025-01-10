# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.12.x]
### Added
- Reject close index requests, while remote store migration is in progress.([#18327](https://github.com/opensearch-project/OpenSearch/pull/18327))

### Dependencies
- Bump `netty` from 4.1.118.Final to 4.1.121.Final ([#18192](https://github.com/opensearch-project/OpenSearch/pull/18192))
- Bump Apache Lucene to 9.12.2 ([#18574](https://github.com/opensearch-project/OpenSearch/pull/18574))
- Bump `commons-beanutils:commons-beanutils` from 1.9.4 to 1.11.0 ([#18401](https://github.com/opensearch-project/OpenSearch/issues/18401))

### Deprecated

### Removed

### Fixed
- Use Bad Request status for InputCoercionException ([#18161](https://github.com/opensearch-project/OpenSearch/pull/18161))
- Avoid NPE if on SnapshotInfo if 'shallow' boolean not present ([#18187](https://github.com/opensearch-project/OpenSearch/issues/18187))
- Null check field names in QueryStringQueryBuilder ([#18194](https://github.com/opensearch-project/OpenSearch/pull/18194))
- Fix illegal argument exception when creating a PIT ([#16781](https://github.com/opensearch-project/OpenSearch/pull/16781))
- Fix the bug of Access denied error when rolling log files ([#18597](https://github.com/opensearch-project/OpenSearch/pull/18597))

### Security

[Unreleased 4.12.x]: https://github.com/wazuh/wazuh-indexer/compare/4.11.0...4.12.0
