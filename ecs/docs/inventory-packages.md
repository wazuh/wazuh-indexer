## `wazuh-states-inventory-packages` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Package Fields](https://www.elastic.co/guide/en/ecs/current/ecs-package.html).

|     | Field name             | Data type | Description                          | Example |
| --- | ---------------------- | --------- | ------------------------------------ | ------- |
|     | `agent.*`              | object    | All the agent fields.                | `       |
|     | `@timestamp`           | date      | Timestamp of the scan.               |         |
|     | `package.architecture` | keyword   | Package architecture.                |         |
|     | `package.description`  | keyword   | Description of the package.          |         |
|     | `package.installed`    | date      | Time when package was installed.     |         |
|     | `package.name`         | keyword   | Package name.                        |         |
|     | `package.path`         | keyword   | Path where the package is installed. |         |
|     | `package.size`         | long      | Package size in bytes.               |         |
|     | `package.type`         | keyword   | Package type.                        |         |
|     | `package.version`      | keyword   | Package version.                     |         |

\* Custom field

<details><summary>Fields not included in ECS</summary>
<p>

|     | Field name | ECS field name    | Data type | Description                                                                    |
| --- | ---------- | ----------------- | --------- | ------------------------------------------------------------------------------ |
| ?   | priority   |                   |           | Priority of the program                                                        |
| ?   | section    |                   |           | Section of the program category the package belongs to in DEB package managers |
| X   | vendor     | package.reference | keyword   | Home page or reference URL of the software in this package, if available.      |
| ?   | multiarch  |                   |           | Multi-architecture compatibility                                               |
| X   | source     |                   |           | Source of the program - package manager                                        |

</p>
</details>

### ECS mapping

```yml
---
name: wazuh-states-inventory-packages
fields:
  base:
    fields:
      "@timestamp": {}
      tags: []
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
      architecture: ""
      description: ""
      installed: {}
      name: ""
      path: ""
      size: {}
      type: ""
      version: ""
```

### Index settings

```json
{
  "index_patterns": ["wazuh-states-inventory-packages*"],
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
          "package.architecture",
          "package.name",
          "package.version",
          "package.type"
        ]
      }
    }
  }
}
```
