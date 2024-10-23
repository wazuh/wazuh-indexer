## `wazuh-states-inventory-system` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).
-   [Operating System Fields](https://www.elastic.co/guide/en/ecs/current/ecs-os.html).

| Field name   | ECS field name      | Data type | Description                                                |
| ------------ | ------------------- | --------- | ---------------------------------------------------------- |
|              | `agent.id`          | keyword   | Agent's ID                                                 |
|              | \*`agent.groups`    | keyword   | Agent's groups                                             |
| scan_time    | `@timestamp`        | date      | Date/time when the event originated.                       |
| architecture | `host.architecture` | keyword   | Operating system architecture.                             |
| hostname     | `host.hostname`     | keyword   | Hostname of the host.                                      |
| os_build     | `host.os.kernel`    | keyword   | Operating system kernel version as a raw string.           |
| os_codename  | `host.os.full`      | keyword   | Operating system name, including the version or code name. |
| os_name      | `host.os.name`      | keyword   | Operating system name, without the version.                |
| os_platform  | `host.os.platform`  | keyword   | Operating system platform (such centos, ubuntu, windows).  |
| os_version   | `host.os.version`   | keyword   | Operating system version as a raw string.                  |
| sysname      | `host.os.type`      | keyword   | [linux, macos, unix, windows, ios, android]                |

\* Custom field

<details><summary>Details</summary>
<p>

Removed fields:

-   os_display_version
-   os_major (can be extracted from os_version)
-   os_minor (can be extracted from os_version)
-   os_patch (can be extracted from os_version)
-   os_release
-   reference
-   release
-   scan_id
-   sysname
-   version
-   checksum

Available fields:

-   `os.family`
-   `hots.name`

</p>
</details>

### ECS mapping

```yml
---
name: wazuh-states-inventory-system
fields:
    base:
        fields:
            "@timestamp": {}
    agent:
        fields:
            id: {}
            groups: {}
    host:
        fields:
            architecture: {}
            hostname: {}
            name: {}
            os:
                fields:
                    kernel: {}
                    full: {}
                    platform: {}
                    version: {}
                    type: {}
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
