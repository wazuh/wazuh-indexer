## `wazuh-states-inventory-system` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).
- [Operating System Fields](https://www.elastic.co/guide/en/ecs/current/ecs-os.html).

|     | Field name          | Data type | Description                                                | Example                    |
| --- | ------------------- | --------- | ---------------------------------------------------------- | -------------------------- |
|     | `agent.*`           | object    | All the agent fields.                                      | `                          |
|     | `@timestamp`        | date      | Date/time when the event originated.                       | `2016-05-23T08:05:34.853Z` |
|     | `host.architecture` | keyword   | Operating system architecture.                             | `x86_64`                   |
|     | `host.hostname`     | keyword   | Hostname of the host.                                      |                            |
|     | `host.os.full`      | keyword   | Operating system name, including the version or code name. | `Mac OS Mojave`            |
|     | `host.os.kernel`    | keyword   | Operating system kernel version as a raw string.           | `4.4.0-112-generic`        |
|     | `host.os.name`      | keyword   | Operating system name, without the version.                | `Mac OS X`                 |
|     | `host.os.platform`  | keyword   | Operating system platform (such centos, ubuntu, windows).  | `darwin`                   |
|     | `host.os.type`      | keyword   | [linux, macos, unix, windows, ios, android]                | `macos`                    |
|     | `host.os.version`   | keyword   | Operating system version as a raw string.                  | `10.14.1`                  |

\* Custom field

<details><summary>Details</summary>
<p>

Removed fields:

- os_display_version
- os_major (can be extracted from os_version)
- os_minor (can be extracted from os_version)
- os_patch (can be extracted from os_version)
- os_release
- reference
- release
- scan_id
- sysname
- version
- checksum

Available fields:

- `os.family`
- `hots.name`

</p>
</details>

### ECS mapping

```yml
---
name: wazuh-states-inventory-system
fields:
  base:
    fields:
      tags: []
      "@timestamp": {}
  agent:
    fields:
      groups: {}
      id: {}
      name: {}
      type: {}
      version: {}
      host:
        fields: "*"
  host:
    fields: "*"
```

### Index settings

```json
{
  "index_patterns": ["wazuh-states-inventory-system*"],
  "priority": 1,
  "template": {
    "settings": {
      "index": {
        "number_of_shards": "1",
        "number_of_replicas": "0",
        "refresh_interval": "5s",
        "query.default_field": [
          "agent.id",
          "agent.groups",
          "host.name",
          "host.os.type",
          "host.os.version"
        ]
      }
    }
  }
}
```
