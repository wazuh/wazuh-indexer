/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The OpenSearch Contributors require contributions made to
 * this file be licensed under the Apache-2.0 license or a
 * compatible open source license.
 */

/*
 * Licensed to Elasticsearch under one or more contributor
 * license agreements. See the NOTICE file distributed with
 * this work for additional information regarding copyright
 * ownership. Elasticsearch licenses this file to you under
 * the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * Modifications Copyright OpenSearch Contributors. See
 * GitHub history for details.
 */

package org.opensearch.bootstrap;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.message.ParameterizedMessage;
import org.apache.lucene.util.Constants;
import org.opensearch.bootstrap.jvm.DenyJvmVersionsParser;
import org.opensearch.cluster.coordination.ClusterBootstrapService;
import org.opensearch.cluster.node.DiscoveryNodeRole;
import org.opensearch.common.SuppressForbidden;
import org.opensearch.common.io.PathUtils;
import org.opensearch.common.settings.Setting;
import org.opensearch.core.common.transport.BoundTransportAddress;
import org.opensearch.core.common.transport.TransportAddress;
import org.opensearch.discovery.DiscoveryModule;
import org.opensearch.env.Environment;
import org.opensearch.index.IndexModule;
import org.opensearch.javaagent.bootstrap.AgentPolicy;
import org.opensearch.monitor.jvm.JvmInfo;
import org.opensearch.monitor.process.ProcessProbe;
import org.opensearch.node.NodeRoleSettings;
import org.opensearch.node.NodeValidationException;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.AllPermission;
import java.security.Policy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static org.opensearch.cluster.coordination.ClusterBootstrapService.INITIAL_CLUSTER_MANAGER_NODES_SETTING;
import static org.opensearch.cluster.coordination.ClusterBootstrapService.INITIAL_MASTER_NODES_SETTING;
import static org.opensearch.discovery.DiscoveryModule.DISCOVERY_SEED_PROVIDERS_SETTING;
import static org.opensearch.discovery.SettingsBasedSeedHostsProvider.DISCOVERY_SEED_HOSTS_SETTING;

/**
 * We enforce bootstrap checks once a node has the transport protocol bound to a non-loopback interface or if the system property {@code
 * opensearch.enforce.bootstrap.checks} is set to {@code true}. In this case we assume the node is running in production and
 * all bootstrap checks must pass.
 *
 * @opensearch.internal
 */
final class BootstrapChecks {

    private BootstrapChecks() {}

    static final String OPENSEARCH_ENFORCE_BOOTSTRAP_CHECKS = "opensearch.enforce.bootstrap.checks";

    /**
     * Executes the bootstrap checks if the node has the transport protocol bound to a non-loopback interface. If the system property
     * {@code opensearch.enforce.bootstrap.checks} is set to {@code true} then the bootstrap checks will be enforced regardless
     * of whether or not the transport protocol is bound to a non-loopback interface.
     *
     * @param context              the current node bootstrap context
     * @param boundTransportAddress the node network bindings
     */
    static void check(
        final BootstrapContext context,
        final BoundTransportAddress boundTransportAddress,
        List<BootstrapCheck> additionalChecks
    ) throws NodeValidationException {
        final List<BootstrapCheck> builtInChecks = checks();
        final List<BootstrapCheck> combinedChecks = new ArrayList<>(builtInChecks);
        combinedChecks.addAll(additionalChecks);
        check(
            context,
            enforceLimits(boundTransportAddress, DiscoveryModule.DISCOVERY_TYPE_SETTING.get(context.settings())),
            Collections.unmodifiableList(combinedChecks)
        );
    }

    /**
     * Executes the provided checks and fails the node if {@code enforceLimits} is {@code true}, otherwise logs warnings. If the system
     * property {@code opensearch.enforce.bootstrap.checks} is set to {@code true} then the bootstrap checks will be enforced
     * regardless of whether or not the transport protocol is bound to a non-loopback interface.
     *
     * @param context        the current node boostrap context
     * @param enforceLimits {@code true} if the checks should be enforced or otherwise warned
     * @param checks        the checks to execute
     */
    static void check(final BootstrapContext context, final boolean enforceLimits, final List<BootstrapCheck> checks)
        throws NodeValidationException {
        check(context, enforceLimits, checks, LogManager.getLogger(BootstrapChecks.class));
    }

    /**
     * Executes the provided checks and fails the node if {@code enforceLimits} is {@code true}, otherwise logs warnings. If the system
     * property {@code opensearch.enforce.bootstrap.checks }is set to {@code true} then the bootstrap checks will be enforced
     * regardless of whether or not the transport protocol is bound to a non-loopback interface.
     *
     * @param context the current node boostrap context
     * @param enforceLimits {@code true} if the checks should be enforced or otherwise warned
     * @param checks        the checks to execute
     * @param logger        the logger to
     */
    static void check(final BootstrapContext context, final boolean enforceLimits, final List<BootstrapCheck> checks, final Logger logger)
        throws NodeValidationException {
        final List<String> errors = new ArrayList<>();
        final List<String> ignoredErrors = new ArrayList<>();

        final String esEnforceBootstrapChecks = System.getProperty(OPENSEARCH_ENFORCE_BOOTSTRAP_CHECKS);
        final boolean enforceBootstrapChecks;
        if (esEnforceBootstrapChecks == null) {
            enforceBootstrapChecks = false;
        } else if (Boolean.TRUE.toString().equals(esEnforceBootstrapChecks)) {
            enforceBootstrapChecks = true;
        } else {
            final String message = String.format(
                Locale.ROOT,
                "[%s] must be [true] but was [%s]",
                OPENSEARCH_ENFORCE_BOOTSTRAP_CHECKS,
                esEnforceBootstrapChecks
            );
            throw new IllegalArgumentException(message);
        }

        if (enforceLimits) {
            logger.info("bound or publishing to a non-loopback address, enforcing bootstrap checks");
        } else if (enforceBootstrapChecks) {
            logger.info("explicitly enforcing bootstrap checks");
        }

        for (final BootstrapCheck check : checks) {
            final BootstrapCheck.BootstrapCheckResult result = check.check(context);
            if (result.isFailure()) {
                if (!(enforceLimits || enforceBootstrapChecks) && !check.alwaysEnforce()) {
                    ignoredErrors.add(result.getMessage());
                } else {
                    errors.add(result.getMessage());
                }
            }
        }

        if (!ignoredErrors.isEmpty()) {
            ignoredErrors.forEach(error -> log(logger, error));
        }

        if (!errors.isEmpty()) {
            final List<String> messages = new ArrayList<>(1 + errors.size());
            messages.add("[" + errors.size() + "] bootstrap checks failed");
            for (int i = 0; i < errors.size(); i++) {
                messages.add("[" + (i + 1) + "]: " + errors.get(i));
            }
            final NodeValidationException ne = new NodeValidationException(String.join("\n", messages));
            errors.stream().map(IllegalStateException::new).forEach(ne::addSuppressed);
            throw ne;
        }
    }

    static void log(final Logger logger, final String error) {
        logger.warn(error);
    }

    /**
     * Tests if the checks should be enforced.
     *
     * @param boundTransportAddress the node network bindings
     * @param discoveryType the discovery type
     * @return {@code true} if the checks should be enforced
     */
    static boolean enforceLimits(final BoundTransportAddress boundTransportAddress, final String discoveryType) {
        final Predicate<TransportAddress> isLoopbackAddress = t -> t.address().getAddress().isLoopbackAddress();
        final boolean bound = !(Arrays.stream(boundTransportAddress.boundAddresses()).allMatch(isLoopbackAddress)
            && isLoopbackAddress.test(boundTransportAddress.publishAddress()));
        return bound && !"single-node".equals(discoveryType);
    }

    // the list of checks to execute
    static List<BootstrapCheck> checks() {
        final List<BootstrapCheck> checks = new ArrayList<>();
        checks.add(new HeapSizeCheck());
        final FileDescriptorCheck fileDescriptorCheck = Constants.MAC_OS_X ? new OsXFileDescriptorCheck() : new FileDescriptorCheck();
        checks.add(fileDescriptorCheck);
        checks.add(new MlockallCheck());
        if (Constants.LINUX) {
            checks.add(new MaxNumberOfThreadsCheck());
        }
        if (Constants.LINUX || Constants.MAC_OS_X) {
            checks.add(new MaxSizeVirtualMemoryCheck());
        }
        if (Constants.LINUX || Constants.MAC_OS_X) {
            checks.add(new MaxFileSizeCheck());
        }
        if (Constants.LINUX) {
            checks.add(new MaxMapCountCheck());
        }
        checks.add(new ClientJvmCheck());
        checks.add(new UseSerialGCCheck());
        checks.add(new SystemCallFilterCheck());
        checks.add(new OnErrorCheck());
        checks.add(new OnOutOfMemoryErrorCheck());
        checks.add(new EarlyAccessCheck());
        checks.add(new JavaVersionCheck());
        checks.add(new AllPermissionCheck());
        checks.add(new DiscoveryConfiguredCheck());
        checks.add(new MultipleDataPathCheck());
        return Collections.unmodifiableList(checks);
    }

    static class JavaVersionCheck implements BootstrapCheck {
        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            return DenyJvmVersionsParser.getDeniedJvmVersions()
                .stream()
                .filter(p -> p.test(getVersion()))
                .findAny()
                .map(
                    p -> BootstrapCheckResult.failure(
                        String.format(Locale.ROOT, "The current JVM version %s is not recommended for use: %s", getVersion(), p.getReason())
                    )
                )
                .orElseGet(() -> BootstrapCheckResult.success());
        }

        Runtime.Version getVersion() {
            return Runtime.version();
        }
    }

    static class HeapSizeCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            final long initialHeapSize = getInitialHeapSize();
            final long maxHeapSize = getMaxHeapSize();
            if (initialHeapSize != 0 && maxHeapSize != 0 && initialHeapSize != maxHeapSize) {
                final String message;
                if (isMemoryLocked()) {
                    message = String.format(
                        Locale.ROOT,
                        "initial heap size [%d] not equal to maximum heap size [%d]; "
                            + "this can cause resize pauses and prevents memory locking from locking the entire heap",
                        getInitialHeapSize(),
                        getMaxHeapSize()
                    );
                } else {
                    message = String.format(
                        Locale.ROOT,
                        "initial heap size [%d] not equal to maximum heap size [%d]; " + "this can cause resize pauses",
                        getInitialHeapSize(),
                        getMaxHeapSize()
                    );
                }
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        long getInitialHeapSize() {
            return JvmInfo.jvmInfo().getConfiguredInitialHeapSize();
        }

        // visible for testing
        long getMaxHeapSize() {
            return JvmInfo.jvmInfo().getConfiguredMaxHeapSize();
        }

        boolean isMemoryLocked() {
            return Natives.isMemoryLocked();
        }

    }

    static class OsXFileDescriptorCheck extends FileDescriptorCheck {

        OsXFileDescriptorCheck() {
            // see constant OPEN_MAX defined in
            // /usr/include/sys/syslimits.h on OS X and its use in JVM
            // initialization in int os:init_2(void) defined in the JVM
            // code for BSD (contains OS X)
            super(10240);
        }

    }

    static class FileDescriptorCheck implements BootstrapCheck {

        private final int limit;

        FileDescriptorCheck() {
            this(65535);
        }

        protected FileDescriptorCheck(final int limit) {
            if (limit <= 0) {
                throw new IllegalArgumentException("limit must be positive but was [" + limit + "]");
            }
            this.limit = limit;
        }

        public final BootstrapCheckResult check(BootstrapContext context) {
            final long maxFileDescriptorCount = getMaxFileDescriptorCount();
            if (maxFileDescriptorCount != -1 && maxFileDescriptorCount < limit) {
                final String message = String.format(
                    Locale.ROOT,
                    "max file descriptors [%d] for opensearch process is too low, increase to at least [%d]",
                    getMaxFileDescriptorCount(),
                    limit
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        long getMaxFileDescriptorCount() {
            return ProcessProbe.getInstance().getMaxFileDescriptorCount();
        }

    }

    static class MlockallCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (BootstrapSettings.MEMORY_LOCK_SETTING.get(context.settings()) && !isMemoryLocked()) {
                return BootstrapCheckResult.failure("memory locking requested for opensearch process but memory is not locked");
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        boolean isMemoryLocked() {
            return Natives.isMemoryLocked();
        }

    }

    static class MaxNumberOfThreadsCheck implements BootstrapCheck {

        // this should be plenty for machines up to 256 cores
        private static final long MAX_NUMBER_OF_THREADS_THRESHOLD = 1 << 12;

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (getMaxNumberOfThreads() != -1 && getMaxNumberOfThreads() < MAX_NUMBER_OF_THREADS_THRESHOLD) {
                final String message = String.format(
                    Locale.ROOT,
                    "max number of threads [%d] for user [%s] is too low, increase to at least [%d]",
                    getMaxNumberOfThreads(),
                    BootstrapInfo.getSystemProperties().get("user.name"),
                    MAX_NUMBER_OF_THREADS_THRESHOLD
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        long getMaxNumberOfThreads() {
            return JNANatives.MAX_NUMBER_OF_THREADS;
        }

    }

    static class MaxSizeVirtualMemoryCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (getMaxSizeVirtualMemory() != Long.MIN_VALUE && getMaxSizeVirtualMemory() != getRlimInfinity()) {
                final String message = String.format(
                    Locale.ROOT,
                    "max size virtual memory [%d] for user [%s] is too low, increase to [unlimited]",
                    getMaxSizeVirtualMemory(),
                    BootstrapInfo.getSystemProperties().get("user.name")
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        long getRlimInfinity() {
            return JNACLibrary.RLIM_INFINITY;
        }

        // visible for testing
        long getMaxSizeVirtualMemory() {
            return JNANatives.MAX_SIZE_VIRTUAL_MEMORY;
        }

    }

    /**
     * Bootstrap check that the maximum file size is unlimited (otherwise OpenSearch could run in to an I/O exception writing files).
     */
    static class MaxFileSizeCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            final long maxFileSize = getMaxFileSize();
            if (maxFileSize != Long.MIN_VALUE && maxFileSize != getRlimInfinity()) {
                final String message = String.format(
                    Locale.ROOT,
                    "max file size [%d] for user [%s] is too low, increase to [unlimited]",
                    getMaxFileSize(),
                    BootstrapInfo.getSystemProperties().get("user.name")
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        long getRlimInfinity() {
            return JNACLibrary.RLIM_INFINITY;
        }

        long getMaxFileSize() {
            return JNANatives.MAX_FILE_SIZE;
        }

    }

    static class MaxMapCountCheck implements BootstrapCheck {

        static final long LIMIT = 1 << 18;

        @Override
        public BootstrapCheckResult check(final BootstrapContext context) {
            // we only enforce the check if a store is allowed to use mmap at all
            if (IndexModule.NODE_STORE_ALLOW_MMAP.get(context.settings())) {
                if (getMaxMapCount() != -1 && getMaxMapCount() < LIMIT) {
                    final String message = String.format(
                        Locale.ROOT,
                        "max virtual memory areas vm.max_map_count [%d] is too low, increase to at least [%d]",
                        getMaxMapCount(),
                        LIMIT
                    );
                    return BootstrapCheckResult.failure(message);
                } else {
                    return BootstrapCheckResult.success();
                }
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        long getMaxMapCount() {
            return getMaxMapCount(LogManager.getLogger(BootstrapChecks.class));
        }

        // visible for testing
        long getMaxMapCount(Logger logger) {
            final Path path = getProcSysVmMaxMapCountPath();
            try (BufferedReader bufferedReader = getBufferedReader(path)) {
                final String rawProcSysVmMaxMapCount = readProcSysVmMaxMapCount(bufferedReader);
                if (rawProcSysVmMaxMapCount != null) {
                    try {
                        return parseProcSysVmMaxMapCount(rawProcSysVmMaxMapCount);
                    } catch (final NumberFormatException e) {
                        logger.warn(() -> new ParameterizedMessage("unable to parse vm.max_map_count [{}]", rawProcSysVmMaxMapCount), e);
                    }
                }
            } catch (final IOException e) {
                logger.warn(() -> new ParameterizedMessage("I/O exception while trying to read [{}]", path), e);
            }
            return -1;
        }

        @SuppressForbidden(reason = "access /proc/sys/vm/max_map_count")
        private Path getProcSysVmMaxMapCountPath() {
            return PathUtils.get("/proc/sys/vm/max_map_count");
        }

        // visible for testing
        BufferedReader getBufferedReader(final Path path) throws IOException {
            return Files.newBufferedReader(path);
        }

        // visible for testing
        String readProcSysVmMaxMapCount(final BufferedReader bufferedReader) throws IOException {
            return bufferedReader.readLine();
        }

        // visible for testing
        long parseProcSysVmMaxMapCount(final String procSysVmMaxMapCount) throws NumberFormatException {
            return Long.parseLong(procSysVmMaxMapCount);
        }

    }

    static class ClientJvmCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (getVmName().toLowerCase(Locale.ROOT).contains("client")) {
                final String message = String.format(
                    Locale.ROOT,
                    "JVM is using the client VM [%s] but should be using a server VM for the best performance",
                    getVmName()
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        String getVmName() {
            return JvmInfo.jvmInfo().getVmName();
        }

    }

    /**
     * Checks if the serial collector is in use. This collector is single-threaded and devastating
     * for performance and should not be used for a server application like OpenSearch.
     */
    static class UseSerialGCCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (getUseSerialGC().equals("true")) {
                final String message = String.format(
                    Locale.ROOT,
                    "JVM is using the serial collector but should not be for the best performance; "
                        + "either it's the default for the VM [%s] or -XX:+UseSerialGC was explicitly specified",
                    JvmInfo.jvmInfo().getVmName()
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        String getUseSerialGC() {
            return JvmInfo.jvmInfo().useSerialGC();
        }

    }

    /**
     * Bootstrap check that if system call filters are enabled, then system call filters must have installed successfully.
     */
    static class SystemCallFilterCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (BootstrapSettings.SYSTEM_CALL_FILTER_SETTING.get(context.settings()) && !isSystemCallFilterInstalled()) {
                final String message = "system call filters failed to install; "
                    + "check the logs and fix your configuration or disable system call filters at your own risk";
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        // visible for testing
        boolean isSystemCallFilterInstalled() {
            return Natives.isSystemCallFilterInstalled();
        }

    }

    abstract static class MightForkCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (isSystemCallFilterInstalled() && mightFork()) {
                return BootstrapCheckResult.failure(message(context));
            } else {
                return BootstrapCheckResult.success();
            }
        }

        abstract String message(BootstrapContext context);

        // visible for testing
        boolean isSystemCallFilterInstalled() {
            return Natives.isSystemCallFilterInstalled();
        }

        // visible for testing
        abstract boolean mightFork();

        @Override
        public final boolean alwaysEnforce() {
            return true;
        }

    }

    static class OnErrorCheck extends MightForkCheck {

        @Override
        boolean mightFork() {
            final String onError = onError();
            return onError != null && !onError.equals("");
        }

        // visible for testing
        String onError() {
            return JvmInfo.jvmInfo().onError();
        }

        @Override
        String message(BootstrapContext context) {
            return String.format(
                Locale.ROOT,
                "OnError [%s] requires forking but is prevented by system call filters ([%s=true]);"
                    + " upgrade to at least Java 8u92 and use ExitOnOutOfMemoryError",
                onError(),
                BootstrapSettings.SYSTEM_CALL_FILTER_SETTING.getKey()
            );
        }

    }

    static class OnOutOfMemoryErrorCheck extends MightForkCheck {

        @Override
        boolean mightFork() {
            final String onOutOfMemoryError = onOutOfMemoryError();
            return onOutOfMemoryError != null && !onOutOfMemoryError.equals("");
        }

        // visible for testing
        String onOutOfMemoryError() {
            return JvmInfo.jvmInfo().onOutOfMemoryError();
        }

        String message(BootstrapContext context) {
            return String.format(
                Locale.ROOT,
                "OnOutOfMemoryError [%s] requires forking but is prevented by system call filters ([%s=true]);"
                    + " upgrade to at least Java 8u92 and use ExitOnOutOfMemoryError",
                onOutOfMemoryError(),
                BootstrapSettings.SYSTEM_CALL_FILTER_SETTING.getKey()
            );
        }

    }

    /**
     * Bootstrap check for early-access builds from OpenJDK.
     */
    static class EarlyAccessCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            final String javaVersion = javaVersion();
            if ("Oracle Corporation".equals(jvmVendor()) && javaVersion.endsWith("-ea")) {
                final String message = String.format(
                    Locale.ROOT,
                    "Java version [%s] is an early-access build, only use release builds",
                    javaVersion
                );
                return BootstrapCheckResult.failure(message);
            } else {
                return BootstrapCheckResult.success();
            }
        }

        String jvmVendor() {
            return Constants.JVM_VENDOR;
        }

        String javaVersion() {
            return Runtime.version().toString();
        }

    }

    static class AllPermissionCheck implements BootstrapCheck {

        @Override
        public final BootstrapCheckResult check(BootstrapContext context) {
            if (isAllPermissionGranted()) {
                return BootstrapCheck.BootstrapCheckResult.failure("granting the all permission effectively disables security");
            }
            return BootstrapCheckResult.success();
        }

        @SuppressWarnings("removal")
        boolean isAllPermissionGranted() {
            final Policy policy = AgentPolicy.getPolicy();
            assert policy != null;
            try {
                AgentPolicy.checkPermission(new AllPermission());
            } catch (final SecurityException e) {
                return false;
            }
            return true;
        }

    }

    static class DiscoveryConfiguredCheck implements BootstrapCheck {
        @Override
        public BootstrapCheckResult check(BootstrapContext context) {

            if (DiscoveryModule.ZEN2_DISCOVERY_TYPE.equals(DiscoveryModule.DISCOVERY_TYPE_SETTING.get(context.settings())) == false) {
                return BootstrapCheckResult.success();
            }
            if (ClusterBootstrapService.discoveryIsConfigured(context.settings())) {
                return BootstrapCheckResult.success();
            }

            return BootstrapCheckResult.failure(
                String.format(
                    Locale.ROOT,
                    // TODO: Remove ' / %s' from the error message after removing MASTER_ROLE, and update unit test.
                    "the default discovery settings are unsuitable for production use; at least one of [%s / %s] must be configured",
                    Stream.of(DISCOVERY_SEED_HOSTS_SETTING, DISCOVERY_SEED_PROVIDERS_SETTING, INITIAL_CLUSTER_MANAGER_NODES_SETTING)
                        .map(Setting::getKey)
                        .collect(Collectors.joining(", ")),
                    INITIAL_MASTER_NODES_SETTING.getKey()
                )
            );
        }
    }

    /**
     * Bootstrap check that if a warm node contains multiple data paths
     */
    static class MultipleDataPathCheck implements BootstrapCheck {

        @Override
        public BootstrapCheckResult check(BootstrapContext context) {
            if (NodeRoleSettings.NODE_ROLES_SETTING.get(context.settings()).contains(DiscoveryNodeRole.WARM_ROLE)
                && Environment.PATH_DATA_SETTING.get(context.settings()).size() > 1) {
                return BootstrapCheckResult.failure("Multiple data paths are not allowed for warm nodes");
            }
            return BootstrapCheckResult.success();
        }

        @Override
        public final boolean alwaysEnforce() {
            return true;
        }

    }
}
