# CHANGELOG
All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See the [CONTRIBUTING guide](./CONTRIBUTING.md#Changelog) for instructions on how to add changelog entries.

## [Unreleased 5.0.0]
### Added
- Add new users, roles and mappings [(#886)](https://github.com/wazuh/wazuh-indexer/pull/886)
- Add custom GitHub Action to validate commiter's emails by domain [(#896)](https://github.com/wazuh/wazuh-indexer/pull/896)

### Changed
- Refactor `if-else` chains to use `Java 17 pattern matching switch expressions`(([#18965](https://github.com/opensearch-project/OpenSearch/pull/18965))
- Add CompletionStage variants to methods in the Client Interface and default to ActionListener impl ([#18998](https://github.com/opensearch-project/OpenSearch/pull/18998))
- IllegalArgumentException when scroll ID references a node not found in Cluster ([#19031](https://github.com/opensearch-project/OpenSearch/pull/19031))
- Adding ScriptedAvg class to painless spi to allowlist usage from plugins ([#19006](https://github.com/opensearch-project/OpenSearch/pull/19006))
- Make field data cache size setting dynamic and add a default limit ([#19152](https://github.com/opensearch-project/OpenSearch/pull/19152))
- Replace centos:8 with almalinux:8 since centos docker images are deprecated ([#19154](https://github.com/opensearch-project/OpenSearch/pull/19154))
- Add CompletionStage variants to IndicesAdminClient as an alternative to ActionListener ([#19161](https://github.com/opensearch-project/OpenSearch/pull/19161))
- Remove cap on Java version used by forbidden APIs ([#19163](https://github.com/opensearch-project/OpenSearch/pull/19163))
- Omit maxScoreCollector for field collapsing when sort by score descending ([#19181](https://github.com/opensearch-project/OpenSearch/pull/19181))
- Disable pruning for `doc_values` for the wildcard field mapper ([#18568](https://github.com/opensearch-project/OpenSearch/pull/18568))
- Make all methods in Engine.Result public ([#19276](https://github.com/opensearch-project/OpenSearch/pull/19275))
- Create and attach interclusterTest and yamlRestTest code coverage reports to gradle check task([#19165](https://github.com/opensearch-project/OpenSearch/pull/19165))
- Optimized date histogram aggregations by preventing unnecessary object allocations in date rounding utils ([19088](https://github.com/opensearch-project/OpenSearch/pull/19088))
- Optimize source conversion in gRPC search hits using zero-copy BytesRef ([#19280](https://github.com/opensearch-project/OpenSearch/pull/19280))
- Allow plugins to copy folders into their config dir during installation ([#19343](https://github.com/opensearch-project/OpenSearch/pull/19343))
- Add failureaccess as runtime dependency to transport-grpc module  ([#19339](https://github.com/opensearch-project/OpenSearch/pull/19339))
- Migrate usages of deprecated `Operations#union` from Lucene ([#19397](https://github.com/opensearch-project/OpenSearch/pull/19397))
- Delegate primitive write methods with ByteSizeCachingDirectory wrapped IndexOutput ([#19432](https://github.com/opensearch-project/OpenSearch/pull/19432))
- Bump opensearch-protobufs dependency to 0.18.0 and update transport-grpc module compatibility ([#19447](https://github.com/opensearch-project/OpenSearch/issues/19447))
- Bump opensearch-protobufs dependency to 0.19.0 ([#19453](https://github.com/opensearch-project/OpenSearch/issues/19453))
- Add a function to SearchPipelineService to check if system generated factory enabled or not ([#19545](https://github.com/opensearch-project/OpenSearch/pull/19545))

### Fixed
- Fix unnecessary refreshes on update preparation failures ([#15261](https://github.com/opensearch-project/OpenSearch/issues/15261))
- Fix NullPointerException in segment replicator ([#18997](https://github.com/opensearch-project/OpenSearch/pull/18997))
- Ensure that plugins that utilize dumpCoverage can write to jacoco.dir when tests.security.manager is enabled ([#18983](https://github.com/opensearch-project/OpenSearch/pull/18983))
- Fix OOM due to large number of shard result buffering ([#19066](https://github.com/opensearch-project/OpenSearch/pull/19066))
- Fix flaky tests in CloseIndexIT by addressing cluster state synchronization issues ([#18878](https://github.com/opensearch-project/OpenSearch/issues/18878))
- [Tiered Caching] Handle  query execution exception ([#19000](https://github.com/opensearch-project/OpenSearch/issues/19000))
- Grant access to testclusters dir for tests ([#19085](https://github.com/opensearch-project/OpenSearch/issues/19085))
- Fix assertion error when collapsing search results with concurrent segment search enabled ([#19053](https://github.com/opensearch-project/OpenSearch/pull/19053))
- Fix skip_unavailable setting changing to default during node drop issue ([#18766](https://github.com/opensearch-project/OpenSearch/pull/18766))
- Fix issue with s3-compatible repositories due to missing checksum trailing headers ([#19220](https://github.com/opensearch-project/OpenSearch/pull/19220))
- Add reference count control in NRTReplicationEngine#acquireLastIndexCommit ([#19214](https://github.com/opensearch-project/OpenSearch/pull/19214))
- Fix pull-based ingestion pause state initialization during replica promotion ([#19212](https://github.com/opensearch-project/OpenSearch/pull/19212))
- Fix QueryPhaseResultConsumer incomplete callback loops ([#19231](https://github.com/opensearch-project/OpenSearch/pull/19231))
- Fix the `scaled_float` precision issue ([#19188](https://github.com/opensearch-project/OpenSearch/pull/19188))
- Fix Using an excessively large reindex slice can lead to a JVM OutOfMemoryError on coordinator.([#18964](https://github.com/opensearch-project/OpenSearch/pull/18964))
- Add alias write index policy to control writeIndex during restore([#1511](https://github.com/opensearch-project/OpenSearch/pull/19368))
- [Flaky Test] Fix flaky test in SecureReactorNetty4HttpServerTransportTests with reproducible seed ([#19327](https://github.com/opensearch-project/OpenSearch/pull/19327))
- Remove unnecessary looping in field data cache clear ([#19116](https://github.com/opensearch-project/OpenSearch/pull/19116))
- [Flaky Test] Fix flaky test IngestFromKinesisIT.testAllActiveIngestion ([#19380](https://github.com/opensearch-project/OpenSearch/pull/19380))
- Fix lag metric for pull-based ingestion when streaming source is empty ([#19393](https://github.com/opensearch-project/OpenSearch/pull/19393))
- Fix IntervalQuery flaky test ([#19332](https://github.com/opensearch-project/OpenSearch/pull/19332))
- Fix ingestion state xcontent serialization in IndexMetadata and fail fast on mapping errors([#19320](https://github.com/opensearch-project/OpenSearch/pull/19320))
- Fix updated keyword field params leading to stale responses from request cache ([#19385](https://github.com/opensearch-project/OpenSearch/pull/19385))
- Fix cardinality agg pruning optimization by self collecting ([#19473](https://github.com/opensearch-project/OpenSearch/pull/19473))
- Implement SslHandler retrieval logic for transport-reactor-netty4 plugin ([#19458](https://github.com/opensearch-project/OpenSearch/pull/19458))
- Cache serialised cluster state based on cluster state version and node version.([#19307](https://github.com/opensearch-project/OpenSearch/pull/19307))
- Fix stats API in store-subdirectory module's SubdirectoryAwareStore ([#19470](https://github.com/opensearch-project/OpenSearch/pull/19470))
- Setting number of sharedArenaMaxPermits to 1 ([#19503](https://github.com/opensearch-project/OpenSearch/pull/19503))
- Handle negative search request nodes stats ([#19340](https://github.com/opensearch-project/OpenSearch/pull/19340))
- Remove unnecessary iteration per-shard in request cache cleanup ([#19263](https://github.com/opensearch-project/OpenSearch/pull/19263))
- Fix derived field rewrite to handle range queries ([#19496](https://github.com/opensearch-project/OpenSearch/pull/19496))
- [WLM] add a check to stop workload group deletion having rules ([#19502](https://github.com/opensearch-project/OpenSearch/pull/19502))
- Fix incorrect rewriting of terms query with more than two consecutive whole numbers ([#19587](https://github.com/opensearch-project/OpenSearch/pull/19587))
- Disable query rewriting framework as a default behaviour ([#19592](https://github.com/opensearch-project/OpenSearch/pull/19592))

### Dependencies
-

### Changed
- Migrate issue templates to 5.0.0 [(#855)](https://github.com/wazuh/wazuh-indexer/pull/855)
- Migrate workflows and scripts from 6.0.0 [(861)](https://github.com/wazuh/wazuh-indexer/pull/861)
- Migrate smoke tests to 5.0.0 [(#863)](https://github.com/wazuh/wazuh-indexer/pull/863)
- Replace and remove deprecated settings [(#894)](https://github.com/wazuh/wazuh-indexer/pull/894)

### Deprecated
-

### Removed
- Remove extra files [(#866)](https://github.com/wazuh/wazuh-indexer/pull/866)

### Fixed
-  Fix package upload to bucket subfolder 5.x [(#846)](https://github.com/wazuh/wazuh-indexer/pull/846)

### Security
-

[Unreleased 5.0.0]: https://github.com/wazuh/wazuh-indexer/compare/4.14.0...5.0.0
