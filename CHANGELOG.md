# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 5.0.0]
### Added
- Add new users, roles and mappings [(#886)](https://github.com/wazuh/wazuh-indexer/pull/886)
- Add custom GitHub Action to validate commiter's emails by domain [(#896)](https://github.com/wazuh/wazuh-indexer/pull/896)
- Migrate to OpenSearch 3.0.0 [(#903)](https://github.com/wazuh/wazuh-indexer/pull/903)
- Add Wazuh version comparison [(#936)](https://github.com/wazuh/wazuh-indexer/pull/936)
- Include Reporting plugin in Wazuh Indexer by default [(#1008)](https://github.com/wazuh/wazuh-indexer/pull/1008)
- Make Wazuh Indexer roles reserved [(#1012)](https://github.com/wazuh/wazuh-indexer/pull/1012)
- Add Cross-Cluster Search environment [(#1034)](https://github.com/wazuh/wazuh-indexer/pull/1034)

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
- Migrate smoke tests from Allocator to docker [(#931)](https://github.com/wazuh/wazuh-indexer/pull/931)
- Migrate builder workflows from [(#930)](https://github.com/wazuh/wazuh-indexer/pull/930)
- Rename bumper workflow file [(#986)](https://github.com/wazuh/wazuh-indexer/pull/986)
- Update previous version in debian workflow test [(#1041)](https://github.com/wazuh/wazuh-indexer/pull/1041)
- Disable multi-tenancy by default [(#1081)](https://github.com/wazuh/wazuh-indexer/pull/1081)
- Add version to the GH Workflow names [(#1124)](https://github.com/wazuh/wazuh-indexer/pull/1124)
- Update GitHub Actions versions in main branch [(#1131)](https://github.com/wazuh/wazuh-indexer/pull/1131)
- Refactor GH workflow to build packages to use a single branch input [(#1145)](https://github.com/wazuh/wazuh-indexer/pull/1145) [(#1169)](https://github.com/wazuh/wazuh-indexer/pull/1169)

### Deprecated
-

### Removed
- Remove extra files [(#866)](https://github.com/wazuh/wazuh-indexer/pull/866) [(#1074)](https://github.com/wazuh/wazuh-indexer/pull/1074)
- Remove references to legacy VERSION file [(#908)](https://github.com/wazuh/wazuh-indexer/pull/908)
- Remove opensearch-performance-analyzer [(#892)](https://github.com/wazuh/wazuh-indexer/pull/892)

### Fixed
- Fix package upload to bucket subfolder 5.x [(#846)](https://github.com/wazuh/wazuh-indexer/pull/846)
- Fix seccomp error on `wazuh-indexer.service` [(#912)](https://github.com/wazuh/wazuh-indexer/pull/912)
- Fix CodeQL workflow [(#963)](https://github.com/wazuh/wazuh-indexer/pull/963)
- Fix auto-generated demo certificates naming [(#1010)](https://github.com/wazuh/wazuh-indexer/pull/1010)
- Fix service status preservation during upgrade in RPM packages [(#1031)](https://github.com/wazuh/wazuh-indexer/pull/1031)
- Fix Deprecation warning due to set-output command [(#1112)](https://github.com/wazuh/wazuh-indexer/pull/1112)
- Fix SysV service script permissions [(#1139)](https://github.com/wazuh/wazuh-indexer/pull/1139)

### Security
- Reduce risk of GITHUB_TOKEN exposure [(#960)](https://github.com/wazuh/wazuh-indexer/pull/960)

[Unreleased 5.0.0]: https://github.com/wazuh/wazuh-indexer/compare/4.14.1...5.0.0
