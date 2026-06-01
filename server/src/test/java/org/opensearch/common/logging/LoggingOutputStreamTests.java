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
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.LogEvent;
import org.apache.logging.log4j.core.appender.AbstractAppender;
import org.apache.logging.log4j.core.config.Property;
import org.opensearch.test.OpenSearchTestCase;
import org.junit.Before;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import static org.opensearch.common.logging.LoggingOutputStream.DEFAULT_BUFFER_LENGTH;
import static org.opensearch.common.logging.LoggingOutputStream.MAX_BUFFER_LENGTH;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;

public class LoggingOutputStreamTests extends OpenSearchTestCase {

    class TestLoggingOutputStream extends LoggingOutputStream {
        List<String> lines = new ArrayList<>();

        TestLoggingOutputStream() {
            super(null, null);
        }

        @Override
        void log(String msg) {
            lines.add(msg);
        }
    }

    TestLoggingOutputStream loggingStream;
    PrintStream printStream;

    @Before
    public void createStream() throws Exception {
        loggingStream = new TestLoggingOutputStream();
        printStream = new PrintStream(loggingStream, false, StandardCharsets.UTF_8.name());
    }

    public void testEmptyLineUnix() {
        printStream.print("\n");
        assertTrue(loggingStream.lines.isEmpty());
        printStream.flush();
        assertTrue(loggingStream.lines.isEmpty());
    }

    public void testEmptyLineWindows() {
        printStream.print("\r\n");
        assertTrue(loggingStream.lines.isEmpty());
        printStream.flush();
        assertTrue(loggingStream.lines.isEmpty());
    }

    public void testNull() {
        printStream.write(0);
        printStream.flush();
        assertTrue(loggingStream.lines.isEmpty());
    }

    // this test explicitly outputs the newlines instead of relying on println, to always test the unix behavior
    public void testFlushOnUnixNewline() {
        printStream.print("hello\n");
        printStream.print("\n"); // newline by itself does not show up
        printStream.print("world\n");
        assertThat(loggingStream.lines, contains("hello", "world"));
    }

    // this test explicitly outputs the newlines instead of relying on println, to always test the windows behavior
    public void testFlushOnWindowsNewline() {
        printStream.print("hello\r\n");
        printStream.print("\r\n"); // newline by itself does not show up
        printStream.print("world\r\n");
        assertThat(loggingStream.lines, contains("hello", "world"));
    }

    public void testBufferExtension() {
        String longStr = randomAlphaOfLength(DEFAULT_BUFFER_LENGTH);
        String extraLongStr = randomAlphaOfLength(DEFAULT_BUFFER_LENGTH + 1);
        printStream.println(longStr);
        assertThat(loggingStream.threadLocal.get().bytes.length, equalTo(DEFAULT_BUFFER_LENGTH));
        printStream.println(extraLongStr);
        assertThat(loggingStream.lines, contains(longStr, extraLongStr));
        assertThat(loggingStream.threadLocal.get().bytes.length, equalTo(DEFAULT_BUFFER_LENGTH));
    }

    public void testMaxBuffer() {
        String longStr = randomAlphaOfLength(MAX_BUFFER_LENGTH);
        String extraLongStr = longStr + "OVERFLOW";
        printStream.println(longStr);
        printStream.println(extraLongStr);
        assertThat(loggingStream.lines, contains(longStr, longStr, "OVERFLOW"));
    }

    public void testClosed() {
        loggingStream.close();
        IOException e = expectThrows(IOException.class, () -> loggingStream.write('a'));
        assertThat(e.getMessage(), containsString("buffer closed"));
    }

    public void testThreadIsolation() throws Exception {
        printStream.print("from thread 1");
        Thread thread2 = new Thread(() -> { printStream.println("from thread 2"); });
        thread2.start();
        thread2.join();
        printStream.flush();
        assertThat(loggingStream.lines, contains("from thread 2", "from thread 1"));
    }

    public void testDetectJulLevelInfo() {
        assertThat(LoggingOutputStream.detectJulLevel("INFO: some message"), equalTo(Level.INFO));
    }

    public void testDetectJulLevelWarning() {
        assertThat(LoggingOutputStream.detectJulLevel("WARNING: some message"), equalTo(Level.WARN));
    }

    public void testDetectJulLevelSevere() {
        assertThat(LoggingOutputStream.detectJulLevel("SEVERE: some message"), equalTo(Level.ERROR));
    }

    public void testDetectJulLevelConfig() {
        assertThat(LoggingOutputStream.detectJulLevel("CONFIG: some message"), equalTo(Level.DEBUG));
    }

    public void testDetectJulLevelFine() {
        assertThat(LoggingOutputStream.detectJulLevel("FINE: some message"), equalTo(Level.TRACE));
        assertThat(LoggingOutputStream.detectJulLevel("FINER: some message"), equalTo(Level.TRACE));
        assertThat(LoggingOutputStream.detectJulLevel("FINEST: some message"), equalTo(Level.TRACE));
    }

    public void testDetectJulLevelNone() {
        assertNull(LoggingOutputStream.detectJulLevel("regular stderr output"));
        assertNull(LoggingOutputStream.detectJulLevel("some error happened"));
    }

    public void testJulInfoMessageLoggedAtInfoLevel() {
        Logger logger = LogManager.getLogger("test.stderr.jul");
        org.apache.logging.log4j.core.Logger coreLogger = (org.apache.logging.log4j.core.Logger) logger;

        List<LogEvent> events = new CopyOnWriteArrayList<>();
        AbstractAppender appender = new AbstractAppender("test", null, null, true, Property.EMPTY_ARRAY) {
            @Override
            public void append(LogEvent event) {
                events.add(event.toImmutable());
            }
        };
        appender.start();
        coreLogger.addAppender(appender);
        coreLogger.setLevel(Level.ALL);

        try {
            LoggingOutputStream stream = new LoggingOutputStream(logger, Level.WARN);
            PrintStream ps = new PrintStream(stream, false, StandardCharsets.UTF_8);

            ps.println("May 25, 2026 1:25:13 PM org.opensearch.javaagent.bootstrap.AgentPolicy setPolicy");
            ps.println("INFO: Policy attached successfully");

            assertThat(events.size(), equalTo(2));
            // Both lines should be logged at INFO level, not WARN
            assertThat(events.get(0).getLevel(), equalTo(Level.INFO));
            assertThat(events.get(0).getMessage().getFormattedMessage(), containsString("AgentPolicy setPolicy"));
            assertThat(events.get(1).getLevel(), equalTo(Level.INFO));
            assertThat(events.get(1).getMessage().getFormattedMessage(), containsString("INFO: Policy attached successfully"));

            ps.close();
        } finally {
            coreLogger.removeAppender(appender);
            appender.stop();
        }
    }

    public void testJulWarningMessageLoggedAtWarnLevel() {
        Logger logger = LogManager.getLogger("test.stderr.jul.warn");
        org.apache.logging.log4j.core.Logger coreLogger = (org.apache.logging.log4j.core.Logger) logger;

        List<LogEvent> events = new CopyOnWriteArrayList<>();
        AbstractAppender appender = new AbstractAppender("test", null, null, true, Property.EMPTY_ARRAY) {
            @Override
            public void append(LogEvent event) {
                events.add(event.toImmutable());
            }
        };
        appender.start();
        coreLogger.addAppender(appender);
        coreLogger.setLevel(Level.ALL);

        try {
            LoggingOutputStream stream = new LoggingOutputStream(logger, Level.WARN);
            PrintStream ps = new PrintStream(stream, false, StandardCharsets.UTF_8);

            ps.println("Jun 01, 2026 10:00:00 AM org.example.SomeClass someMethod");
            ps.println("WARNING: something went wrong");

            assertThat(events.size(), equalTo(2));
            // Both lines should be logged at WARN level
            assertThat(events.get(0).getLevel(), equalTo(Level.WARN));
            assertThat(events.get(1).getLevel(), equalTo(Level.WARN));

            ps.close();
        } finally {
            coreLogger.removeAppender(appender);
            appender.stop();
        }
    }

    public void testRegularStderrStillLoggedAtDefaultLevel() {
        Logger logger = LogManager.getLogger("test.stderr.regular");
        org.apache.logging.log4j.core.Logger coreLogger = (org.apache.logging.log4j.core.Logger) logger;

        List<LogEvent> events = new CopyOnWriteArrayList<>();
        AbstractAppender appender = new AbstractAppender("test", null, null, true, Property.EMPTY_ARRAY) {
            @Override
            public void append(LogEvent event) {
                events.add(event.toImmutable());
            }
        };
        appender.start();
        coreLogger.addAppender(appender);
        coreLogger.setLevel(Level.ALL);

        try {
            LoggingOutputStream stream = new LoggingOutputStream(logger, Level.WARN);
            PrintStream ps = new PrintStream(stream, false, StandardCharsets.UTF_8);

            ps.println("some random third-party stderr output");

            assertThat(events.size(), equalTo(1));
            // Regular stderr should still be logged at WARN (the default)
            assertThat(events.get(0).getLevel(), equalTo(Level.WARN));
            assertThat(events.get(0).getMessage().getFormattedMessage(), containsString("some random third-party stderr output"));

            ps.close();
        } finally {
            coreLogger.removeAppender(appender);
            appender.stop();
        }
    }

    public void testLucenePanamaVectorizationInfoMessage() {
        Logger logger = LogManager.getLogger("test.stderr.lucene");
        org.apache.logging.log4j.core.Logger coreLogger = (org.apache.logging.log4j.core.Logger) logger;

        List<LogEvent> events = new CopyOnWriteArrayList<>();
        AbstractAppender appender = new AbstractAppender("test", null, null, true, Property.EMPTY_ARRAY) {
            @Override
            public void append(LogEvent event) {
                events.add(event.toImmutable());
            }
        };
        appender.start();
        coreLogger.addAppender(appender);
        coreLogger.setLevel(Level.ALL);

        try {
            LoggingOutputStream stream = new LoggingOutputStream(logger, Level.WARN);
            PrintStream ps = new PrintStream(stream, false, StandardCharsets.UTF_8);

            ps.println("May 25, 2026 1:25:14 PM org.apache.lucene.internal.vectorization.PanamaVectorizationProvider");
            ps.println("INFO: Java vector incubator API enabled; uses preferredBitSize=256; FMA enabled");

            assertThat(events.size(), equalTo(2));
            // Both should be at INFO level
            assertThat(events.get(0).getLevel(), equalTo(Level.INFO));
            assertThat(events.get(1).getLevel(), equalTo(Level.INFO));

            ps.close();
        } finally {
            coreLogger.removeAppender(appender);
            appender.stop();
        }
    }
}
