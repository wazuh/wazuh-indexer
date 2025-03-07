# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 4.12.x]
### Added
- Add `scanner.condition` custom field to vulnerability detector index definition ([#637](https://github.com/wazuh/wazuh-indexer/pull/637))
- Enable assembly of ARM packages [(#444)](https://github.com/wazuh/wazuh-indexer/pull/444)

### Changed
- Make telemetry `Tags` immutable ([#20788](https://github.com/opensearch-project/OpenSearch/pull/20788))
- Move Randomness from server to libs/common ([#20570](https://github.com/opensearch-project/OpenSearch/pull/20570))
- Use env variable (OPENSEARCH_FIPS_MODE) to enable opensearch to run in FIPS enforced mode instead of checking for existence of bcFIPS jars ([#20625](https://github.com/opensearch-project/OpenSearch/pull/20625))
- Update streaming flag to use search request context ([#20530](https://github.com/opensearch-project/OpenSearch/pull/20530))
- Move pull-based ingestion classes from experimental to publicAPI ([#20704](https://github.com/opensearch-project/OpenSearch/pull/20704))
- Lazy init stored field reader in SourceLookup ([#20827](https://github.com/opensearch-project/OpenSearch/pull/20827))
* Improved error message when trying to open an index originally created with Elasticsearch on OpenSearch ([#20512](https://github.com/opensearch-project/OpenSearch/pull/20512))
- Updated MMapDirectory to use ReadAdviseByContext rather than default readadvise of Lucene([#21031](https://github.com/opensearch-project/OpenSearch/pull/21031))

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

### Changed
- Version file standarization [[#693]](https://github.com/wazuh/wazuh-indexer/pull/693)

### Deprecated

### Removed

### Fixed
- Fix startup errors on STIG compliant systems due to noexec filesystems [(#533)](https://github.com/wazuh/wazuh-indexer/pull/533)

### Security
- Migration to OpenSearch 2.19.0 (JDK 21 and Gradle 8.2) [(#702)](https://github.com/wazuh/wazuh-indexer/pull/702)

[Unreleased 4.12.x]: https://github.com/wazuh/wazuh-indexer/compare/b62bb89ac9278a9c67d27b68db34e9381ecb0aca...4.12.0
