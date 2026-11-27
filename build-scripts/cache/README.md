# Package build cache

The package build can restore the plugin repositories and the OpenSearch core from a cache instead of building them. It is off by default: `builder.sh` uses it only when it gets `-C STORE`, and publishes to it only with `-P`, which only trusted builds pass. Local builds and the workflows that don't pass `-C` behave as before.

## What is cached

| Entry | Content | Shared by |
| :-- | :-- | :-- |
| `wazuh-indexer-common-utils`, `-alerting`, `-security-analytics`, `-notifications`, `-reporting`, `-plugins` | What the repository publishes to the Maven local repository (`com/wazuh/<artifact>/<version>/`): the plugin zips the package installs, and the jars and POMs the later repositories compile against. | All targets. The plugins don't depend on the architecture or the distribution: built for the four targets, every class and resource of the Wazuh plugins is the same, only the build dates in `META-INF/MANIFEST.MF` differ. |
| `core-<distribution>-<architecture>` | The min package that `build.sh` builds and the internal plugin zips (`workload-management`). | One target. The bundled JDK and a few platform files depend on the architecture; the systemd unit, `opensearch-env` and the env file are expanded per distribution. |

## Keys

A key is the SHA-256 of a short text listing every input that decides the artifact. `cache-key.sh -x` prints that text.

**Plugins**: the epoch, the repository commit (a full SHA; `builder.sh` resolves branches and tags first and builds exactly that commit), the product version and revision passed as `-Dversion`/`-Drevision`, a hash of `builder/entrypoint.sh` (the Gradle invocations), and the keys of the repositories it compiles against:

```
common-utils ─┬─ alerting ── security-analytics ── plugins
              ├─ notifications
              └─ reporting
```

So a common-utils change rebuilds everything, a reporting change only reporting. The OpenSearch version the plugins compile against is set in each repository (`opensearch.version`, `3.6.0-SNAPSHOT`), so it comes with the commit. What the snapshot resolves to does not: `3.6.0-SNAPSHOT` was last published on 2026-04-10, and a new publication of it would not invalidate the plugins.

**Core**: the epoch, the distribution, the architecture, the `version` field of `VERSION.json`, and the git hash of every file of the repository except those in `core.exclude` (plus those in `core.include`). The working tree counts, committed or not, untracked files included and ignored files left out. The excluded files are:

- repository tooling and documentation (`.github/`, `build-scripts/` except `build.sh` and `product_version.sh`, root Markdown files except `README.md`, which is bundled);
- files `assemble.sh` reads from the repository: the RPM spec, the DEB `debian/` scripts, `Makefile` and `debmake_install.sh`, `distribution/src/lib/`;
- files bundled in the min package but read by `assemble.sh` from the repository: `opensearch.prod.yml` and the `security/*.wazuh.yml` files;
- `VERSION.json`, of which only `version` reaches the core.

Anything not excluded is an input, new files included: a missing exclusion costs a cache miss, a wrong one ships stale content. The other Wazuh files bundled in the min package (`resolve-credentials.sh`, `indexer-security-init.sh`, the systemd unit, `jvm.options`...) stay in the key. Some are expanded per distribution by Gradle, so the assembly could not copy them from the repository as they are.

`test_cache_key.sh` checks these rules on a throwaway clone (one change per case, whether the key moves or not). Run it after changing `core.exclude`, `core.include` or `cache-key.sh`.

## Invalidating everything

Raise the number in `epoch` when something outside the keys changes what the build produces: the builder image toolchain (JDK major version, operating system, Gradle policy), or the layout of the entries. Every key changes, and the old entries expire. Each entry records the JDK and machine it was built with in its manifest.

## Store

`store.sh` reads and writes entries in `file:///absolute/path` (local runs, tests) or `s3://bucket/prefix`. An entry is `<store>/<name>/<key>/`, with a payload (a tar of the entry, under a name unique to the writer) and `manifest.json`, written last with a conditional write (`If-None-Match: *` on S3). A reader trusts only entries with a manifest and checks the payload SHA-256 against it. When two builds publish the same key at once, the first manifest wins, the other build keeps going, and its payload is left to the store expiry. The builds are not byte-for-byte reproducible (the jar manifests carry the build date), so two entries of one key can differ in those dates.

A failure to read is a miss, and a failure to publish is a warning: neither fails the package build. Expiry and access control belong to the store (S3 lifecycle rule, bucket policy, publish role).

## Flow

1. `builder.sh` (host) resolves the plugin refs to commits, computes the keys into `artifacts/cache/keys`, and downloads the hits into `artifacts/cache/restore/<name>/`.
2. `entrypoint.sh` (container) restores each hit instead of building it, and copies each artifact it builds to `artifacts/cache/publish/<name>/`. The container never gets store credentials.
3. `builder.sh` publishes `artifacts/cache/publish/*` when given `-P`, after a successful build.

The log states a hit or a miss and the key of every entry.

## Effects of a restored entry

- `GET /` reports the `build_hash` and `build_date` of the build that produced the core, and every jar keeps the `Change` and `Build-Date` of the build that produced it. `VERSION.json` in the package, generated by the assembly, always names the commits packaged.
- The min package is stored under a fixed name and renamed after the current commits when restored, so the package name always reflects the commits packaged.

## Running it locally

```bash
cd build-scripts/builder
bash builder.sh -e <engine tarball> -d deb -a x64 \
    -p 5.0.0 -r 5.0.0 -s 5.0.0 -n 5.0.0 -t 5.0.0 -c 5.0.0 \
    -C file:///tmp/indexer-cache -P
```

The second run with the same inputs restores everything and only assembles the package.
