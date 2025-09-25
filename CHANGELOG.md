# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.14.x]
### Added
- Add check to confirm if wazuh-indexer service is running after upgrade [(#940)](https://github.com/wazuh/wazuh-indexer/pull/940)
- Add users and groups ECS mappings [(#890)](https://github.com/wazuh/wazuh-indexer/pull/890)
- Add index definition for the new index `wazuh-states-inventory-services` [(#1057)](https://github.com/wazuh/wazuh-indexer/pull/1057)
- Add index definition for the new index `wazuh-states-inventory-browser-extensions` [(#1058)](https://github.com/wazuh/wazuh-indexer/pull/1058)

### Dependencies
-

### Changed
- Reorganize ecs folder [(#899)](https://github.com/wazuh/wazuh-indexer/pull/899)
- Update workflow naming on 4.14.0 branch [(#1095)](https://github.com/wazuh/wazuh-indexer/pull/1095)
- Add version to the GH Workflow names [(#1123)](https://github.com/wazuh/wazuh-indexer/pull/1123)
- Update GitHub Actions versions in 4.14.0 [(#1130)](https://github.com/wazuh/wazuh-indexer/pull/1130)

### Deprecated
-

### Removed
-   

### Fixed
-

### Security
- Migrate 4.14.0 to OpenSearch 2.19.3 [(#1050)](https://github.com/wazuh/wazuh-indexer/pull/1050)

[Unreleased 4.14.x]: https://github.com/wazuh/wazuh-indexer/compare/b7e222a823164da076c3482b511ab08b3e7b8384...4.14.0
