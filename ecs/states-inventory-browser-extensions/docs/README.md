## `wazuh-states-inventory-browser-extensions` index data model

### Fields summary

The fields are based on:
- [Inventory - Browser Extensions mappings](https://github.com/wazuh/wazuh-agent/issues/805#issuecomment-3050200310) (included in 4.14.0)

Based on osquery and ECS:

- [chrome extensions table](https://osquery.io/schema/5.16.0/#chrome_extensions).
- [firefox addons table](https://osquery.io/schema/5.16.0/#firefox_addons).
- [ie extensions table](https://osquery.io/schema/5.16.0/#ie_extensions).
- [safari extensions table](https://osquery.io/schema/5.16.0/#safari_extensions).
- [Package fields](https://www.elastic.co/docs/reference/ecs/ecs-package).

The detail of the fields can be found in csv file [Inventory Browser Extensions Fields](fields.csv).

### Transition table

| #   | Custom | ECS Field Name               | Type        | Source(s)                                                 | Browser / OS            | Description                                             |
| --- | ------ | ---------------------------- | ----------- | --------------------------------------------------------- | ----------------------- | ------------------------------------------------------- |
| 1   | 1      | `browser.name`               | `keyword`   | `chrome_extensions.browser_type`                          | All                     | Browser name: `chrome`, `firefox`, `safari`, `ie`, etc. |
| 2   | 0      | `user.id`                    | `keyword`   | `*_extensions.uid` or `firefox_addons.uid`                | All except IE           | Local user who owns the extension                       |
| 3   | 0      | `package.name`               | `keyword`   | `name` (all tables)                                       | All                     | Display name of the extension                           |
| 4   | 1      | `package.id`                 | `keyword`   | `identifier`, `referenced_identifier`, `registry_path`    | All                     | Unique identifier of the extension                      |
| 5   | 0      | `package.version`            | `keyword`   | `version`, `bundle_version`                               | All                     | Extension version                                       |
| 6   | 0      | `package.description`        | `keyword`   | `description`                                             | All                     | Optional description                                    |
| 7   | 1      | `package.vendor`             | `keyword`   | `author`, `creator`, `copyright`                          | Chrome, Firefox, Safari | Author or creator                                       |
| 8   | 0      | `package.build_version`      | `keyword`   | `safari_extensions.sdk`                                   | Safari                  | Bundle SDK used to compile the extension                |
| 9   | 0      | `package.path`               | `keyword`   | `path`                                                    | All                     | Path to extension files or manifest                     |
| 10  | 1      | `browser.profile.name`       | `keyword`   | `chrome_extensions.profile`                               | Chrome                  | Chrome profile name                                     |
| 11  | 1      | `browser.profile.path`       | `keyword`   | `chrome_extensions.profile_path`                          | Chrome                  | File system path to the Chrome profile                  |
| 12  | 0      | `package.reference`          | `keyword`   | `chrome_extensions.update_url`                            | Chrome                  | Update URL for the extension                            |
| 13  | 1      | `package.permissions`        | `keyword[]` | `permissions`, `permissions_json`, `optional_permissions` | Chrome                  | Required or optional permissions                        |
| 14  | 0      | `package.reference`          | `keyword`   | `firefox_addons.source_url`                               | Firefox                 | URL that installed the addon                            |
| 15  | 0      | `package.type`               | `keyword`   | `firefox_addons.type`                                     | Firefox                 | Type of addon: `extension`, `webapp`, etc.              |
| 16  | 1      | `package.enabled`            | `boolean`   | `state`, `active`, `disabled`, `visible`                  | Chrome, Firefox         | Whether the extension is enabled.                       |
| 17  | 1      | `package.visible`            | `boolean`   | `firefox_addons.visible`                                  | Firefox                 | Whether the addon is visible in the toolbar             |
| 18  | 1      | `package.autoupdate`         | `boolean`   | `firefox_addons.autoupdate`                               | Firefox                 | If the addon uses background updates                    |
| 19  | 1      | `package.persistent`         | `boolean`   | `chrome_extensions.persistent`                            | Chrome                  | Persistent across tabs (1 or 0)                         |
| 20  | 1      | `package.from_webstore`      | `boolean`   | `chrome_extensions.from_webstore`                         | Chrome                  | Installed from webstore                                 |
| 21  | 1      | `browser.profile.referenced` | `boolean`   | `chrome_extensions.referenced`                            | Chrome                  | Referenced by Chrome Preferences                        |
| 22  | 0      | `package.installed`          | `date`      | `install_time` / `install_timestamp`                      | Chrome                  | Install time (epoch)                                    |
| 23  | 0      | `file.hash.sha256`           | `keyword`   | `manifest_hash`                                           | Chrome                  | SHA256 of manifest.json                                 |
