## `wazuh-states-inventory-hardware` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).
-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).

|     | Field name   | ECS field name                | Data type | Description                      |
| --- | ------------ | ----------------------------- | --------- | -------------------------------- |
|     | scan_time    | @timestamp                    | date      | Timestamp of the scan            |
|     | board_serial | observer.serial_number        | keyword   | Serial number of the motherboard |
| *   | cpu_name     | host.cpu.name               | keyword   | Name of the CPU                  |
| *   | cpu_cores    | host.cpu.cores              | long      | Number of CPU cores              |
| *   | cpu_mhz      | host.cpu.speed              | long      | Speed of the CPU in MHz          |
| *   | ram_total    | host.memory.total           | long      | Total RAM in the system          |
| *   | ram_free     | host.memory.free            | long      | Free RAM in the system           |
| *   | ram_usage    | host.memory.used.percentage | long      | RAM usage as a percentage        |

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
      id: {}
      groups: {}
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
  "index_patterns": [
    "wazuh-states-inventory-hardware*"
  ],
  "priority": 1,
  "template": {
    "settings": {
      "index": {
        "number_of_replicas": "0",
        "number_of_shards": "1",
        "query.default_field": [
          "observer.board_serial"
        ],
        "refresh_interval": "5s"
      }
    },
    "mappings": {
      "date_detection": false,
      "dynamic": "strict",
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "agent": {
          "properties": {
            "groups": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "host": {
          "properties": {
            "cpu": {
              "properties": {
                "cores": {
                  "type": "long"
                },
                "name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "speed": {
                  "type": "long"
                }
              },
              "type": "object"
            },
            "memory": {
              "properties": {
                "free": {
                  "type": "long"
                },
                "total": {
                  "type": "long"
                },
                "used": {
                  "properties": {
                    "percentage": {
                      "type": "long"
                    }
                  },
                  "type": "object"
                }
              },
              "type": "object"
            }
          }
        },
        "observer": {
          "properties": {
            "serial_number": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        }
      }
    }
  }
}

```
