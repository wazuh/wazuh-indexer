## `wazuh-states-inventory-hotfixes` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Package Fields](https://www.elastic.co/guide/en/ecs/current/ecs-package.html).

|     | Field name            | Data type | Description           | Example                    |
| --- | --------------------- | --------- | --------------------- | -------------------------- |
|     | `agent.*`             | object    | All the agent fields. | `                          |
|     | `@timestamp`          | date      | Timestamp of the scan | `2016-05-23T08:05:34.853Z` |
| \*  | `package.hotfix.name` | keyword   | Name of the hotfix    |                            |

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
      groups: {}
      id: {}
      name: {}
      type: {}
      version: {}
      host:
        fields: "*"
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
        "number_of_shards": "1",
        "number_of_replicas": "0",
        "refresh_interval": "5s",
        "query.default_field": [
          "package.hotfix.name"
        ]
      }
    }
  }
}
```
