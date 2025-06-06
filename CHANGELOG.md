# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 5.0.0]
### Added
- Add new users, roles and mappings [(#886)](https://github.com/wazuh/wazuh-indexer/pull/886)
- Add custom GitHub Action to validate commiter's emails by domain [(#896)](https://github.com/wazuh/wazuh-indexer/pull/896)
- Migrate to OpenSearch 3.0.0 [(#903)](https://github.com/wazuh/wazuh-indexer/pull/903)

### Dependencies
-

### Changed
- Migrate issue templates to 5.0.0 [(#855)](https://github.com/wazuh/wazuh-indexer/pull/855)
- Migrate workflows and scripts from 6.0.0 [(861)](https://github.com/wazuh/wazuh-indexer/pull/861)
- Migrate smoke tests to 5.0.0 [(#863)](https://github.com/wazuh/wazuh-indexer/pull/863)
- Replace and remove deprecated settings [(#894)](https://github.com/wazuh/wazuh-indexer/pull/894)
- Backport packaging improvements [(#906)](https://github.com/wazuh/wazuh-indexer/pull/906)
- Apply Lintian overrides [(#908)](https://github.com/wazuh/wazuh-indexer/pull/908)
- Add noninteractive option for DEB packages testing [(#914)](https://github.com/wazuh/wazuh-indexer/pull/914)
- Migrate builder workflows from [(#930)](https://github.com/wazuh/wazuh-indexer/pull/930)

### Deprecated
-

### Removed
- Remove extra files [(#866)](https://github.com/wazuh/wazuh-indexer/pull/866)
- Remove references to legacy VERSION file [(#908)](https://github.com/wazuh/wazuh-indexer/pull/908)
- Remove opensearch-performance-analyzer [(#892)](https://github.com/wazuh/wazuh-indexer/pull/892)

### Fixed
- Fix package upload to bucket subfolder 5.x [(#846)](https://github.com/wazuh/wazuh-indexer/pull/846)
- Fix seccomp error on `wazuh-indexer.service` [(#912)](https://github.com/wazuh/wazuh-indexer/pull/912)

### Security
-

[Unreleased 5.0.0]: https://github.com/wazuh/wazuh-indexer/compare/4.14.0...5.0.0
