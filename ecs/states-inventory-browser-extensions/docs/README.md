## `wazuh-states-inventory-browser-extensions` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-agent/issues/805#issuecomment-3050200310

Based on osquery and ECS:

- [chrome extensions table](https://osquery.io/schema/5.16.0/#chrome_extensions).
- [firefox addons table](https://osquery.io/schema/5.16.0/#firefox_addons).
- [ie extensions table](https://osquery.io/schema/5.16.0/#ie_extensions).
- [safari extensions table](https://osquery.io/schema/5.16.0/#safari_extensions).

Detailed information about the fields can be found in the [fields.csv](fields.csv) file.

### Transition table

| #   | Custom | ECS Field Name                                    | Type      | Source(s)                                                 | Browser / OS            | Description                                             |
| --- | ------ | ------------------------------------------------- | --------- | --------------------------------------------------------- | ----------------------- | ------------------------------------------------------- |
| 1   | 1      | `browser.name`                                    | `text`    | `chrome_extensions.browser_type`                          | All                     | Browser name: `chrome`, `firefox`, `safari`, `ie`, etc. |
| 2   | 0      | `user.id`                                         | `bigint`  | `*_extensions.uid` or `firefox_addons.uid`                | All except IE           | Local user who owns the extension                       |
| 3   | 0      | package.name `extension.name`                     | `text`    | `name` (all tables)                                       | All                     | Display name of the extension                           |
| 4   | 1      | package.id `extension.id`                         | `text`    | `identifier`, `referenced_identifier`, `registry_path`    | All                     | Unique identifier of the extension                      |
| 5   | 0      | package.version  `extension.version`              | `text`    | `version`, `bundle_version`                               | All                     | Extension version                                       |
| 6   | 0      | package.description  `extension.description`      | `text`    | `description`                                             | All                     | Optional description                                    |
| 7   | 1      | package.vendor  `extension.author`                | `text`    | `author`, `creator`, `copyright`                          | Chrome, Firefox, Safari | Author or creator                                       |
| 8   | 0      | package.build_version  `extension.sdk`            | `text`    | `safari_extensions.sdk`                                   | Safari                  | Bundle SDK used to compile the extension                |
| 9   | 0      | package.path  `extension.path`                    | `text`    | `path`                                                    | All                     | Path to extension files or manifest                     |
| 10  | 1      | browser.profile.name `extension.profile.name`     | `text`    | `chrome_extensions.profile`                               | Chrome                  | Chrome profile name                                     |
| 11  | 1      | browser.profile.path `extension.profile.path`     | `text`    | `chrome_extensions.profile_path`                          | Chrome                  | File system path to the Chrome profile                  |
| 12  | 0      | package.reference `extension.update_address`      | `text`    | `chrome_extensions.update_url`                            | Chrome                  | Update URL for the extension                            |
| 13  | 1      | package.permissions `extension.permissions`       | `text`    | `permissions`, `permissions_json`, `optional_permissions` | Chrome                  | Required or optional permissions                        |
| 14  | 0      | package.reference `extension.source.address`      | `text`    | `firefox_addons.source_url`                               | Firefox                 | URL that installed the addon                            |
| 15  | 0      | package.type `extension.type`                     | `text`    | `firefox_addons.type`                                     | Firefox                 | Type of addon: `extension`, `webapp`, etc.              |
| 16  | 1      | package.enabled `extension.enabled`               | `boolean` | `state`, `active`, `disabled`, `visible`                  | All                     | Whether the extension is enabled                        |
| 17  | 1      | package.autoupdate `extension.autoupdate`         | `boolean` | `firefox_addons.autoupdate`                               | Firefox                 | If the addon uses background updates                    |
| 18  | 1      | package.persistent `extension.persistent`         | `boolean` | `chrome_extensions.persistent`                            | Chrome                  | Persistent across tabs (1 or 0)                         |
| 19  | 1      | package.from_webstore `extension.from_webstore`   | `boolean` | `chrome_extensions.from_webstore`                         | Chrome                  | Installed from webstore                                 |
| 20  | 1      | browser.profile.referenced `extension.referenced` | `boolean` | `chrome_extensions.referenced`                            | Chrome                  | Referenced by Chrome Preferences                        |
| 21  | 0      | package.installed `extension.installed`           | `text`    | `install_time` / `install_timestamp`                      | Chrome                  | Original install time (WebKit or Unix timestamp)        |
| 22  | 1      | manifest.hash.sha256 `extension.manifest.hash`    | `text`    | `manifest_hash`                                           | Chrome                  | SHA256 of manifest.json                                 |
| 23  | 1      | manifest.raw `extension.manifest.json`            | `text`    | `manifest_json`                                           | Chrome                  | Raw manifest.json content                               |
| 24  | ?      | manifest.id `extension.manifest.key`              | `text`    | `key`                                                     | Chrome                  | Extension key from manifest                             |
