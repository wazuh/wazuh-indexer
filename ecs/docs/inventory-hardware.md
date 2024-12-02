## `wazuh-states-inventory-hardware` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).
- [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).

|     | Field name                    | Data type | Description                          | Example                    |
| --- | ----------------------------- | --------- | ------------------------------------ | -------------------------- |
|     | `agent.*`                     | object    | All the agent fields.                | `                          |
|     | `@timestamp`                  | date      | Date/time when the event originated. | `2016-05-23T08:05:34.853Z` |
|     | `observer.serial_number`      | keyword   | Observer serial number.              |                            |
| \*  | `host.cpu.name`               | keyword   | Name of the CPU                      |                            |
| \*  | `host.cpu.cores`              | long      | Number of CPU cores                  |                            |
| \*  | `host.cpu.speed`              | long      | Speed of the CPU in MHz              |                            |
| \*  | `host.memory.total`           | long      | Total RAM in the system              |                            |
| \*  | `host.memory.free`            | long      | Free RAM in the system               |                            |
| \*  | `host.memory.used.percentage` | long      | RAM usage as a percentage            |                            |

\* Custom fields

### ECS mapping

```yml
---
name: wazuh-states-inventory-hardware
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
  observer:
    fields:
      serial_number: {}
  host:
    fields:
      memory:
        fields:
          total: {}
          free: {}
          used:
            fields:
              percentage: {}
      cpu:
        fields:
          name: {}
          cores: {}
          speed: {}
```

### Index settings

```json
{
  "index_patterns": ["wazuh-states-inventory-hardware*"],
  "priority": 1,
  "template": {
    "settings": {
      "index": {
        "number_of_shards": "1",
        "number_of_replicas": "0",
        "refresh_interval": "5s",
        "query.default_field": ["observer.board_serial"]
      }
    }
  }
}
```
