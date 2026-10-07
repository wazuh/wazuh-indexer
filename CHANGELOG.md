## [v5.0.0]

### Added

| Issue | Comment |
|-------|---------|
| [(#1995)](https://github.com/wazuh/wazuh-indexer/issues/1995) | Bundle the Wazuh Engine in the Wazuh Indexer packages and Docker images, and manage its lifecycle with the `wazuh-indexer` service |
| [#1105](https://github.com/wazuh/wazuh-indexer-plugins/issues/1105) | Bundle CTI content snapshots in the Wazuh Indexer packages |
| [#1927](https://github.com/wazuh/wazuh-indexer/issues/1927) [#1975](https://github.com/wazuh/wazuh-indexer/issues/1975) | Generate indexer credentials and TLS material at install time instead of shipping defaults |
| [#462](https://github.com/wazuh/wazuh-indexer-plugins/issues/462) [#1538](https://github.com/wazuh/wazuh-indexer/issues/1538) [#528](https://github.com/wazuh/wazuh-indexer-plugins/issues/528) [#1422](https://github.com/wazuh/wazuh-indexer-plugins/issues/1422) [#1195](https://github.com/wazuh/wazuh-indexer/issues/1195) | Add default Wazuh Indexer users and roles |
| [#1636](https://github.com/wazuh/wazuh-indexer/issues/1636) [#1662](https://github.com/wazuh/wazuh-indexer/issues/1662) [#1249](https://github.com/wazuh/wazuh-indexer/issues/1249) [#1782](https://github.com/wazuh/wazuh-indexer/issues/1782) | Add performance improvements & default configurations |
| [#1299](https://github.com/wazuh/wazuh-indexer/issues/1299) [#1365](https://github.com/wazuh/wazuh-indexer/issues/1365) | Add support for ARM architecture in Wazuh Indexer Docker images |
| [#1576](https://github.com/wazuh/wazuh-indexer/issues/1576) | Add `workload-management` plugin |
| [#1271](https://github.com/wazuh/wazuh-indexer-plugins/issues/1271) | Add `opensearch-custom-codecs` plugin |
| [#857](https://github.com/wazuh/wazuh-indexer/issues/857) | Add `wazuh-indexer-setup` plugin |
| [#1996](https://github.com/wazuh/wazuh-indexer/issues/1996) | Add `wazuh-indexer-content-manager` plugin |
| [#1](https://github.com/wazuh/wazuh-indexer-reporting/issues/1) [#999](https://github.com/wazuh/wazuh-indexer/issues/999) | Add `wazuh-indexer-reports-scheduler` plugin, replacing `opensearch-reports-scheduler` |
| [#1](https://github.com/wazuh/wazuh-indexer-security-analytics/issues/1) [#1270](https://github.com/wazuh/wazuh-indexer/issues/1270) | Add `wazuh-indexer-security-analytics` plugin, a fork of `opensearch-security-analytics` |
| [#1](https://github.com/wazuh/wazuh-indexer-alerting/issues/1) | Add `wazuh-indexer-alerting` plugin, replacing `opensearch-alerting` |
| [#2](https://github.com/wazuh/wazuh-indexer-notifications/issues/2) [#1335](https://github.com/wazuh/wazuh-indexer/issues/1335) | Add `wazuh-indexer-notifications` and `wazuh-indexer-notifications-core` plugins, replacing `opensearch-notifications` and `opensearch-notifications-core` |

### Changed

| Issue | Comment |
|-------|---------|
| [#874](https://github.com/wazuh/wazuh-indexer/issues/874) [#1000](https://github.com/wazuh/wazuh-indexer/issues/1000) [#1086](https://github.com/wazuh/wazuh-indexer/issues/1086) [#1177](https://github.com/wazuh/wazuh-indexer/issues/1177) [#1207](https://github.com/wazuh/wazuh-indexer/issues/1207) [#1284](https://github.com/wazuh/wazuh-indexer/issues/1284) [#1332](https://github.com/wazuh/wazuh-indexer/issues/1332) [#1410](https://github.com/wazuh/wazuh-indexer/issues/1410) [#1341](https://github.com/wazuh/wazuh-indexer/issues/1341) | Upgrade to OpenSearch 3.6.0 and JDK 25 |
| [#1653](https://github.com/wazuh/wazuh-indexer/issues/1653) [#1661](https://github.com/wazuh/wazuh-indexer/issues/1661) | Refuse package upgrades from Wazuh Indexer 4.x, which require a clean installation |
| [#1927](https://github.com/wazuh/wazuh-indexer/issues/1927) | Ship the `admin`, `kibanaserver` and `wazuh-manager` users without a usable password hash |
| [#1670](https://github.com/wazuh/wazuh-indexer/issues/1670) | Enable memory locking (`bootstrap.memory_lock`) by default |
| [#1080](https://github.com/wazuh/wazuh-indexer/issues/1080) | Disable multi-tenancy by default |
| [#1572](https://github.com/wazuh/wazuh-indexer/issues/1572) | Set `OPENSEARCH_TMPDIR` to `/var/lib/wazuh-indexer/tmp` to avoid exhausting the `/tmp` partition |
| [#1581](https://github.com/wazuh/wazuh-indexer/issues/1581) | Log the disabled automatic import of dangling indices at `INFO` instead of `WARN` on every startup |
| [#1998](https://github.com/wazuh/wazuh-indexer/issues/1998) | Enable transport hostname verification (`transport.ssl.enforce_hostname_verification`) by default |


### Removed

| Issue | Comment |
|-------|---------|
| [#893](https://github.com/wazuh/wazuh-indexer/issues/893) [#874](https://github.com/wazuh/wazuh-indexer/issues/874) | Remove deprecated OpenSearch settings in 3.0.0 from `opensearch.yml` |
| [#891](https://github.com/wazuh/wazuh-indexer/issues/891) | Remove `opensearch-performance-analyzer` plugin |
| [#1272](https://github.com/wazuh/wazuh-indexer-plugins/issues/1272) | Remove `opensearch-anomaly-detection` plugin |
| [#1272](https://github.com/wazuh/wazuh-indexer-plugins/issues/1272) | Remove `opensearch-asynchronous-search` plugin |
| [#1577](https://github.com/wazuh/wazuh-indexer/issues/1577) | Remove `opensearch-knn` plugin |
| [#1582](https://github.com/wazuh/wazuh-indexer/issues/1582) | Remove `opensearch-ml` plugin |
| [#1577](https://github.com/wazuh/wazuh-indexer/issues/1577) | Remove `opensearch-neural-search` plugin |
| [#1272](https://github.com/wazuh/wazuh-indexer-plugins/issues/1272) | Remove `opensearch-observability` plugin |
| [#1580](https://github.com/wazuh/wazuh-indexer/issues/1580) | Remove `opensearch-sql` plugin |
| [#1927](https://github.com/wazuh/wazuh-indexer/issues/1927) | Remove the OpenSearch demo users `anomalyadmin`, `kibanaro`, `logstash`, `readall` and `snapshotrestore`, and the demo role mappings, including `own_index` for every user |

### Fixed

| Issue | Comment |
|-------|---------|
| [#1532](https://github.com/wazuh/wazuh-indexer/issues/1532) | Fix the ownership and permissions of `/etc/default/wazuh-indexer` in DEB packages |

## Prior versions
