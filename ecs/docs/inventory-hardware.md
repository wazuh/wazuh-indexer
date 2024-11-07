## `wazuh-states-inventory-hardware` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Device Fields](https://www.elastic.co/guide/en/ecs/current/ecs-device.html).
-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-device.html).

|     | Field name   | ECS field name                | Data type | Description                      |
| --- | ------------ | ----------------------------- | --------- | -------------------------------- |
|     | scan_time    | @timestamp                    | date      | Timestamp of the scan            |
|     | board_serial | observer.serial_number        | keyword   | Serial number of the motherboard |
| *   | cpu_name     | device.cpu.name               | keyword   | Name of the CPU                  |
| *   | cpu_cores    | device.cpu.cores              | long      | Number of CPU cores              |
| *   | cpu_mhz      | device.cpu.speed              | long      | Speed of the CPU in MHz          |
| *   | ram_total    | device.memory.total           | long      | Total RAM in the system          |
| *   | ram_free     | device.memory.free            | long      | Free RAM in the system           |
| *   | ram_usage    | device.memory.used.percentage | long      | RAM usage as a percentage        |

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
  observer:
    fields:
      serial_number: {}
```

### Index settings

```json
{
  "index_patterns": [
    "wazuh-states-inventory-hardware*"
  ],
  "priority": 1,
  "template": {
    "settings": {
      "index": {
        "number_of_shards": "1",
        "number_of_replicas": "0",
        "refresh_interval": "5s",
        "query.default_field": [
          "observer.board_serial"
        ]
      }
    }
  }
}
```
