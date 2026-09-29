/*
 * Copyright Wazuh Indexer Contributors
 * SPDX-License-Identifier: Apache-2.0
 *
 * The Wazuh Indexer Contributors require contributions made to
 * this file be licensed under the Apache-2.0 license or a
 * compatible open source license.
 */

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.opensearch.common.settings.Settings;
import org.opensearch.env.Environment;

/**
 * Prints every directory an opensearch.yml points the node at -- path.home, path.data,
 * path.logs, path.repo and path.shared_data -- one absolute path per line.
 *
 * The package's prerm / %preun runs it while opensearch.yml still exists, so that the purge can
 * hand those directories over to root before it deletes the service account. It reads the file
 * with OpenSearch's own settings loader, so it accepts exactly what the node accepts: flat or
 * nested keys, a single value or a list.
 *
 * It exits non-zero, printing nothing, whenever it cannot say for certain: the file cannot be
 * read or parsed, or a value is relative or holds a placeholder the node would resolve from its
 * own environment. The purge then keeps the account rather than guess.
 *
 * Run it with the bundled JDK, in source-file mode:
 *
 *   jdk/bin/java -cp "lib/*" bin/ListDataPaths.java /etc/wazuh-indexer/opensearch.yml
 */
public class ListDataPaths {

    public static void main(String[] args) {
        try {
            // Null values are accepted: a setting left empty elsewhere in the file -- the admin DN
            // before the credentials are resolved, say -- says nothing about where data lives.
            Path file = Path.of(args[0]);
            Settings settings = Settings.builder()
                .loadFromStream(file.getFileName().toString(), Files.newInputStream(file), true)
                .build();

            List<String> values = new ArrayList<>();
            values.add(Environment.PATH_HOME_SETTING.get(settings));
            values.addAll(Environment.PATH_DATA_SETTING.get(settings));
            values.add(Environment.PATH_LOGS_SETTING.get(settings));
            values.addAll(Environment.PATH_REPO_SETTING.get(settings));
            values.add(Environment.PATH_SHARED_DATA_SETTING.get(settings));

            List<Path> paths = new ArrayList<>();
            for (String value : values) {
                if (value == null || value.isEmpty()) {
                    continue; // not set: the node uses a default, which the purge already covers
                }
                if (value.indexOf('$') >= 0) {
                    throw new IllegalArgumentException("placeholder in " + value);
                }
                Path path = Path.of(value);
                if (path.isAbsolute() == false) {
                    throw new IllegalArgumentException("relative path " + value);
                }
                paths.add(path.normalize());
            }

            // Only once every value is known to be good: a partial list would read as a complete one.
            paths.forEach(System.out::println);
        } catch (Exception e) {
            System.err.println("ListDataPaths: " + e.getMessage());
            System.exit(1);
        }
    }
}
