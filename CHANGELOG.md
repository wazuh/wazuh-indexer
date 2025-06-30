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

### Fixed
- Relax index template pattern overlap check to use minimum-string heuristic, allowing distinguishable multi-wildcard patterns at the same priority ([#20702](https://github.com/opensearch-project/OpenSearch/pull/20702))
- Fix `AutoForceMergeMetrics` silently dropping tags due to unreassigned `addTag()` return value ([#20788](https://github.com/opensearch-project/OpenSearch/pull/20788))
- Fix flaky test failures in ShardsLimitAllocationDeciderIT ([#20375](https://github.com/opensearch-project/OpenSearch/pull/20375))
- Prevent criteria update for context aware indices ([#20250](https://github.com/opensearch-project/OpenSearch/pull/20250))
- Update EncryptedBlobContainer to adhere limits while listing blobs in specific sort order if wrapped blob container supports ([#20514](https://github.com/opensearch-project/OpenSearch/pull/20514))
- [segment replication] Fix segment replication infinite retry due to stale metadata checkpoint ([#20551](https://github.com/opensearch-project/OpenSearch/pull/20551))
- Changing opensearch.cgroups.hierarchy.override causes java.lang.SecurityException exception ([#20565](https://github.com/opensearch-project/OpenSearch/pull/20565))
- Fix CriteriaBasedCodec to work with delegate codec. ([#20442](https://github.com/opensearch-project/OpenSearch/pull/20442))
- Fix WLM workload group creation failing due to updated_at clock skew ([#20486](https://github.com/opensearch-project/OpenSearch/pull/20486))
- Fix copy_to functionality for geo_point fields with object/array values ([#20542](https://github.com/opensearch-project/OpenSearch/pull/20542))
- Fix SLF4J component error ([#20587](https://github.com/opensearch-project/OpenSearch/pull/20587))
- Service does not start on Windows with OpenJDK ([#20615](https://github.com/opensearch-project/OpenSearch/pull/20615))
- Update RemoteClusterStateCleanupManager to performed batched deletions of stale ClusterMetadataManifests and address deletion timeout issues ([#20566](https://github.com/opensearch-project/OpenSearch/pull/20566))
- Fix the regression of terms agg optimization at high cardinality ([#20623](https://github.com/opensearch-project/OpenSearch/pull/20623))
- Leveraging segment-global ordinal mapping for efficient terms aggregation ([#20624](https://github.com/opensearch-project/OpenSearch/pull/20624))
- Support Docker distribution builds for ppc64le, arm64 and s390x ([#20678](https://github.com/opensearch-project/OpenSearch/pull/20678))
- Harden detection of HTTP/3 support by ensuring Quic native libraries are available for the target platform ([#20680](https://github.com/opensearch-project/OpenSearch/pull/20680))
- Fallback to netty client if AWS Crt client is not available on the target platform / architecture ([#20698](https://github.com/opensearch-project/OpenSearch/pull/20698))
- Fix ShardSearchFailure in transport-grpc ([#20641](https://github.com/opensearch-project/OpenSearch/pull/20641))
- Fix TLS cert hot-reload for Arrow Flight transport ([#20732](https://github.com/opensearch-project/OpenSearch/pull/20732))
- Fix misleading heap usage cancellation message in SearchBackpressureService ([#20779](https://github.com/opensearch-project/OpenSearch/pull/20779))
- Fix task details JSON logs with nested JSON in metadata are not properly escaped ([#20802](https://github.com/opensearch-project/OpenSearch/pull/20802))
- Delegate getMin/getMax methods for ExitableTerms ([#20775](https://github.com/opensearch-project/OpenSearch/pull/20775))
- Fix terms lookup subquery fetch limit reading from non-existent index setting instead of cluster `max_clause_count` ([#20823](https://github.com/opensearch-project/OpenSearch/pull/20823))
- Fix array_index_out_of_bounds_exception with wildcard and aggregations ([#20842](https://github.com/opensearch-project/OpenSearch/pull/20842))
- Fix stale segment cleanup logic for remote store ([#20976](https://github.com/opensearch-project/OpenSearch/pull/20976))
- Ensure that transient ThreadContext headers with propagators survive restore ([#169373](https://github.com/opensearch-project/OpenSearch/pull/20854))
- Remove X-Request-Id format restrictions and make size configurable ([#21048](https://github.com/opensearch-project/OpenSearch/pull/21048))
- Handle dependencies between analyzers ([#19248](https://github.com/opensearch-project/OpenSearch/pull/19248))
- Fix `_field_caps` returning empty results and corrupted field names for `disable_objects: true` mappings ([#20800](https://github.com/opensearch-project/OpenSearch/pull/20800))

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

### Deprecated
-

### Removed
- Remove extra files [(#866)](https://github.com/wazuh/wazuh-indexer/pull/866)
- Remove references to legacy VERSION file [(#908)](https://github.com/wazuh/wazuh-indexer/pull/908)
- Remove opensearch-performance-analyzer [(#892)](https://github.com/wazuh/wazuh-indexer/pull/892)

### Fixed
- Fix package upload to bucket subfolder 5.x [(#846)](https://github.com/wazuh/wazuh-indexer/pull/846)
- Fix seccomp error on `wazuh-indexer.service` [(#912)](https://github.com/wazuh/wazuh-indexer/pull/912)
- Fix CodeQL workflow [(#963)](https://github.com/wazuh/wazuh-indexer/pull/963)

### Security
- Reduce risk of GITHUB_TOKEN exposure [(#960)](https://github.com/wazuh/wazuh-indexer/pull/960)

[Unreleased 5.0.0]: https://github.com/wazuh/wazuh-indexer/compare/4.14.0...5.0.0
