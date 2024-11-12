## `wazuh-states-inventory-hardware` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).
-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).

|     | Field name                  | Data type | Description                          | Example                  |
| --- | --------------------------- | --------- | ------------------------------------ | ------------------------ |
|     | @timestamp                  | date      | Date/time when the event originated. | 2016-05-23T08:05:34.853Z |
|     | observer.serial_number      | keyword   | Observer serial number.              |                          |
| *   | host.cpu.name               | keyword   | Name of the CPU                      |                          |
| *   | host.cpu.cores              | long      | Number of CPU cores                  |                          |
| *   | host.cpu.speed              | long      | Speed of the CPU in MHz              |                          |
| *   | host.memory.total           | long      | Total RAM in the system              |                          |
| *   | host.memory.free            | long      | Free RAM in the system               |                          |
| *   | host.memory.used.percentage | long      | RAM usage as a percentage            |                          |

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
