## `wazuh-states-inventory-ports` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
- [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).
- [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).

|     | Field name                   | Data type | Description                                    | Example                                |
| --- | ---------------------------- | --------- | ---------------------------------------------- | -------------------------------------- |
|     | `agent.*`                    | object    | All the agent fields.                          | `                                      |
|     | `@timestamp`                 | date      | Timestamp of the scan.                         | `2016-05-23T08:05:34.853Z`             |
|     | `destination.ip`             | ip        | IP address of the destination.                 | `["192.168.0.100"]`                    |
|     | `destination.port`           | long      | Port of the destination.                       |                                        |
|     | `device.id`                  | keyword   | The unique identifier of a device.             | `00000000-54b3-e7c7-0000-000046bffd97` |
|     | `file.inode`                 | keyword   | Inode representing the file in the filesystem. | `256383`                               |
|     | `network.protocol`           | keyword   | Application protocol name.                     | `http`                                 |
|     | `process.name`               | keyword   | Process name.                                  | `ssh`                                  |
|     | `process.pid`                | long      | Process ID.                                    | `4242`                                 |
|     | `source.ip`                  | ip        | IP address of the source.                      | `["192.168.0.100"]`                    |
|     | `source.port`                | long      | Port of the source.                            |                                        |
| \*  | `host.network.egress.queue`  | long      | Transmit queue length.                         |                                        |
| \*  | `host.network.ingress.queue` | long      | Receive queue length.                          |                                        |
| \*  | `interface.state`            | keyword   | State of the network interface.                |                                        |

\* Custom fields

### ECS mapping

```yml
---
name: wazuh-states-inventory-ports
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
  destination:
    fields:
      ip: {}
      port: {}
  device:
    fields:
      id: {}
  file:
    fields:
      inode: {}
  host:
    fields: 
      network:
        fields:
          egress:
            fields:
              queue: {}
          ingress:
            fields:
              queue: {}
  network:
    fields:
      protocol: {}
  process:
    fields:
      name: {}
      pid: {}
  source:
    fields:
      ip: {}
      port: {}
  interface:
    fields:
      state: {}
```

### Index settings

```json
{
  "index_patterns": [
    "wazuh-states-inventory-ports*"
  ],
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
          "process.name",
          "source.ip",
          "destination.ip"
        ]
      }
    }
  }
}
```
