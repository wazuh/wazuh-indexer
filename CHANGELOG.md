# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.12.x]
### Added
- Add `scanner.condition` custom field to vulnerability detector index definition ([#637](https://github.com/wazuh/wazuh-indexer/pull/637))
- Enable assembly of ARM packages [(#444)](https://github.com/wazuh/wazuh-indexer/pull/444)
- Add `vulnerability.scanner.reference` field to VD and alerts indexes [(#689)](https://github.com/wazuh/wazuh-indexer/pull/689)

### Dependencies

### Changed
- Version file standarization [(#693)](https://github.com/wazuh/wazuh-indexer/pull/693)
- Redesign the mechanism to preserve the status of the service on upgrades [(#794)](https://github.com/wazuh/wazuh-indexer/pull/794)

### Deprecated

### Removed
- Removed unused GitHub Workflows [(#762)](https://github.com/wazuh/wazuh-indexer/pull/762)

### Fixed
- Fix startup errors on STIG compliant systems due to noexec filesystems [(#533)](https://github.com/wazuh/wazuh-indexer/pull/533)
- Fix CI Docker environment [(#760)](https://github.com/wazuh/wazuh-indexer/pull/760)

### Security
- Migration to OpenSearch 2.19.0 (JDK 21 and Gradle 8.12) [(#702)](https://github.com/wazuh/wazuh-indexer/pull/702)
- Migration to OpenSearch 2.19.1 [(#739)](https://github.com/wazuh/wazuh-indexer/pull/739)

[Unreleased 4.12.x]: https://github.com/wazuh/wazuh-indexer/compare/b62bb89ac9278a9c67d27b68db34e9381ecb0aca...4.12.0
