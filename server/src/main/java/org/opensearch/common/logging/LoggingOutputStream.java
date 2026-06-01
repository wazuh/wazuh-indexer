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

package org.opensearch.common.logging;

import org.apache.logging.log4j.Level;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * A stream whose output is sent to the configured logger, line by line.
 *
 * @opensearch.internal
 */
class LoggingOutputStream extends OutputStream {
    /** The starting length of the buffer */
    static final int DEFAULT_BUFFER_LENGTH = 1024;

    // limit a single log message to 64k
    static final int MAX_BUFFER_LENGTH = DEFAULT_BUFFER_LENGTH * 64;

    /**
     * Pattern matching JUL SimpleFormatter header lines, e.g.:
     * "May 25, 2026 1:25:13 PM org.opensearch.javaagent.bootstrap.AgentPolicy setPolicy"
     */
    private static final Pattern JUL_HEADER_PATTERN = Pattern.compile(
        "^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},\\s+\\d{4}\\s+\\d{1,2}:\\d{2}:\\d{2}\\s+(AM|PM)\\s+\\S+"
    );

    class Buffer {

        /** The buffer of bytes sent to the stream */
        byte[] bytes = new byte[DEFAULT_BUFFER_LENGTH];

        /** Number of used bytes in the buffer */
        int used = 0;
    }

    // each thread gets its own buffer so messages don't get garbled
    ThreadLocal<Buffer> threadLocal = ThreadLocal.withInitial(Buffer::new);

    // per-thread pending JUL header line awaiting level detection from the next line
    private final ThreadLocal<String> pendingJulHeader = new ThreadLocal<>();

    private final Logger logger;

    private final Level level;

    LoggingOutputStream(Logger logger, Level level) {
        this.logger = logger;
        this.level = level;
    }

    @Override
    public void write(int b) throws IOException {
        if (threadLocal == null) {
            throw new IOException("buffer closed");
        }
        if (b == 0) return;
        if (b == '\n') {
            // always flush with newlines instead of adding to the buffer
            flush();
            return;
        }

        Buffer buffer = threadLocal.get();

        if (buffer.used == buffer.bytes.length) {
            if (buffer.bytes.length >= MAX_BUFFER_LENGTH) {
                // don't let the buffer get infinitely big
                flush();
                // we reset the buffer in flush so get the new instance
                buffer = threadLocal.get();
            } else {
                // extend the buffer
                buffer.bytes = Arrays.copyOf(buffer.bytes, 2 * buffer.bytes.length);
            }
        }

        buffer.bytes[buffer.used++] = (byte) b;
    }

    @Override
    public void flush() {
        Buffer buffer = threadLocal.get();
        if (buffer.used == 0) return;
        int used = buffer.used;
        if (buffer.bytes[used - 1] == '\r') {
            // windows case: remove the first part of newlines there too
            --used;
        }
        if (used == 0) {
            // only windows \r was in the buffer
            buffer.used = 0;
            return;
        }
        log(new String(buffer.bytes, 0, used, StandardCharsets.UTF_8));
        if (buffer.bytes.length != DEFAULT_BUFFER_LENGTH) {
            threadLocal.set(new Buffer()); // reset size
        } else {
            buffer.used = 0;
        }
    }

    @Override
    public void close() {
        // Flush any pending JUL header before closing
        String header = pendingJulHeader.get();
        if (header != null) {
            logger.log(level, header);
            pendingJulHeader.remove();
        }
        threadLocal = null;
    }

    // pkg private for testing
    void log(String msg) {
        Level detectedLevel = detectJulLevel(msg);
        if (detectedLevel != null) {
            // This line starts with a JUL level prefix (e.g., "INFO: message")
            String header = pendingJulHeader.get();
            if (header != null) {
                logger.log(detectedLevel, header);
                pendingJulHeader.remove();
            }
            logger.log(detectedLevel, msg);
        } else if (JUL_HEADER_PATTERN.matcher(msg).find()) {
            // This line matches a JUL SimpleFormatter header; buffer it until we see the level line
            String previousHeader = pendingJulHeader.get();
            if (previousHeader != null) {
                // Flush the previous unbounded header at default level
                logger.log(level, previousHeader);
            }
            pendingJulHeader.set(msg);
        } else {
            // Regular stderr output
            String header = pendingJulHeader.get();
            if (header != null) {
                logger.log(level, header);
                pendingJulHeader.remove();
            }
            logger.log(level, msg);
        }
    }

    /**
     * Detects a JUL-style level prefix at the start of a message and returns the corresponding Log4j level.
     * Returns null if no JUL level prefix is found.
     */
    static Level detectJulLevel(String msg) {
        String upper = msg.toUpperCase(Locale.ROOT);
        if (upper.startsWith("INFO:")) {
            return Level.INFO;
        } else if (upper.startsWith("WARNING:")) {
            return Level.WARN;
        } else if (upper.startsWith("SEVERE:")) {
            return Level.ERROR;
        } else if (upper.startsWith("CONFIG:")) {
            return Level.DEBUG;
        } else if (upper.startsWith("FINE:") || upper.startsWith("FINER:") || upper.startsWith("FINEST:")) {
            return Level.TRACE;
        }
        return null;
    }
}
