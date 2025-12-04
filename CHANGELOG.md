# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.14.x]
### Added
- Add compatibility with OpenSearch 2.19.4 [#1230](https://github.com/wazuh/wazuh-indexer/issues/1230)

### Dependencies
-

### Changed
- Update indexer-security-init.sh to allow hyphens in domains [(#1240)](https://github.com/wazuh/wazuh-indexer/pull/1240)

### Deprecated
-

### Removed
- 

### Fixed
- Fix broken link generation from the repository bumper script [(#1206)](https://github.com/wazuh/wazuh-indexer/pull/1206)
- Fix indexer-security-init script to use `http.port` instead of `transport.port` [(#1233)](https://github.com/wazuh/wazuh-indexer/pull/1233)
- Fix unscaped commands in indexer-security-init.sh [(#1196)](https://github.com/wazuh/wazuh-indexer/pull/1196)

### Security
- 

[Unreleased 4.14.x]: https://github.com/wazuh/wazuh-indexer/compare/69825f3eeac86127979f128d18bb01ff1c645fb2...4.14.2
