## `wazuh-states-inventory-hotfixes` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Package Fields](https://www.elastic.co/guide/en/ecs/current/ecs-package.html).

|     | Field name          | Data type | Description           | Example |
| --- | ------------------- | --------- | --------------------- | ------- |
|     | @timestamp          | date      | Timestamp of the scan |         |
| *   | package.hotfix.name | keyword   | Name of the hotfix    |         |

\* Custom fields

### ECS mapping

```yml
---
name: wazuh-states-inventory-hotfixes
fields:
  base:
    fields:
      tags: []
      "@timestamp": {}
  agent:
    fields:
      id: {}
      groups: {}
  package:
    fields:
      hotfix:
        fields:
          name: {}
```

### Index settings

```json
{
  "index_patterns": [
    "wazuh-states-inventory-hotfixes*"
  ],
  "priority": 1,
  "template": {
    "settings": {
      "index": {
        "number_of_replicas": "0",
        "number_of_shards": "1",
        "query.default_field": [
          "package.hotfix.name"
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
        "package": {
          "properties": {
            "hotfix": {
              "properties": {
                "name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              },
              "type": "object"
            }
          }
        }
      }
    }
  }
}

```
