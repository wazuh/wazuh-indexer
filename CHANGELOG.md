# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.10.x]
### Added

### Dependencies

### Changed
- Update workflow naming on 4.10.4 branch [(#1092)](https://github.com/wazuh/wazuh-indexer/pull/1092)
- Backport: Redesign the mechanism to preserve the status of the service on upgrades [(#794)](https://github.com/wazuh/wazuh-indexer/pull/794)

### Deprecated

### Removed
- Removed unused GitHub Workflows [(#967)](https://github.com/wazuh/wazuh-indexer/pull/967)

### Fixed
- Fix segment replication failure during rolling restart ([#19234](https://github.com/opensearch-project/OpenSearch/issues/19234))
- Fix SearchPhaseExecutionException to properly initCause ([#20336](https://github.com/opensearch-project/OpenSearch/pull/20336))

### Security
- Reduce risk of GITHUB_TOKEN exposure [(#972)](https://github.com/wazuh/wazuh-indexer/pull/972)

[Unreleased 4.10.x]: https://github.com/wazuh/wazuh-indexer/compare/v4.10.3...4.10.4
