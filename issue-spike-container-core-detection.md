# Title: [SPIKE] Investigate whether OpenSearch correctly detects CPU cores inside containers

## Description

This is a **SPIKE** (time-boxed investigation, no implementation deliverable beyond findings and a recommendation).

We need to determine whether the Wazuh indexer (OpenSearch) correctly detects the number of CPU cores available to it when running inside a container (Docker, Kubernetes, or any cgroup-constrained environment), or whether it reads the number of cores of the **host** and ignores the container's CPU limit/quota.

This matters because OpenSearch sizes many of its thread pools and internal parallelism from the detected processor count. If the component sees the host's cores instead of the container's allocation, thread pools are over-provisioned relative to the CPU actually available, which can cause context-switching overhead, resource contention, and instability. This is thematically related to the recent work on default configurations to avoid node OOM crashes (#1701) — both are about the indexer respecting the resources it is actually granted inside a container.

**What we already know from the code (paths relative to repo root):**

- The processor count ultimately comes from `Runtime.getRuntime().availableProcessors()`:
  - `server/src/main/java/org/opensearch/common/util/concurrent/OpenSearchExecutors.java` — `PROCESSORS_SETTING` defaults to `Runtime.getRuntime().availableProcessors()`; `NODE_PROCESSORS_SETTING` (the `node.processors` setting) is derived from it, and `allocatedProcessors(Settings)` returns that value.
  - `server/src/main/java/org/opensearch/threadpool/ThreadPool.java` — thread pool sizes (`WRITE`, `GENERIC`, `SNAPSHOT`, half-processor pools, etc.) are computed from `allocatedProcessors`.
  - `server/src/main/java/org/opensearch/monitor/os/OsProbe.java` (~line 619) and `OsInfo` — reports `availableProcessors` in node/OS info and cluster stats (`ClusterStatsNodes`).
- There is an override: the `node.processors` setting (`NODE_PROCESSORS_SETTING`) lets an operator pin the processor count manually.

**Open question:** modern JVMs (JDK 10+ with `UseContainerSupport`) are supposed to make `Runtime.availableProcessors()` honor the cgroup CPU quota. We need to verify this actually holds for the JVM/JDK the Wazuh indexer ships with, across cgroup v1 and v2, and for both hard CPU limits (`--cpus` / `cpu.max`) and CPU shares.

## Functional requirements

The spike must produce written findings that answer:

- Does `Runtime.getRuntime().availableProcessors()` — as observed by the Wazuh indexer inside a container — return the container's allocated cores or the host's cores?
- Does the answer differ across: cgroup v1 vs v2; hard CPU limits (`--cpus`, `cpu.max`, CPU quota/period) vs CPU shares (`--cpu-shares`); fractional CPU limits (e.g. `--cpus=1.5`)?
- Which JDK/JVM version does the shipped indexer bundle, and is `UseContainerSupport` enabled by default in it?
- What value ends up in the thread pool sizing and in `GET _nodes/os` (`available_processors` / `allocated_processors`) under a CPU limit?
- Is the existing `node.processors` setting a sufficient workaround, and if so what guidance/defaults should we ship (link back to #1701's config approach)?

## Implementation restrictions

- No production code changes as part of this spike — the deliverable is a findings document plus a recommendation (and, if warranted, a follow-up implementation/config issue).
- Testing should use the actual indexer container image / JVM we ship, not an arbitrary local JDK, so results reflect production behavior.

## Plan

- [ ] Identify the exact JDK/JVM bundled with the Wazuh indexer and confirm whether `UseContainerSupport` is on by default.
- [ ] Reproduce: run the indexer in Docker with an explicit CPU limit (e.g. `--cpus=2` on a host with more cores) and inspect `GET _nodes/os` for `available_processors` / `allocated_processors`, plus thread pool sizes via `GET _nodes/thread_pool` / `_cat/thread_pool`.
- [ ] Repeat under cgroup v1 and cgroup v2 hosts.
- [ ] Repeat with CPU shares (`--cpu-shares`) and fractional limits (`--cpus=1.5`) to see how each is rounded/interpreted.
- [ ] Compare detected value against the container's real allocation; document any mismatch.
- [ ] Test whether setting `node.processors` correctly overrides detection and produces the expected thread pool sizing.
- [ ] Investigate the Kubernetes case (CPU requests vs limits) if relevant to our deployments (`wazuh-docker` / Helm).
- [ ] Write up findings and a recommendation: is a fix/default-config change needed, and if so open a follow-up issue.
