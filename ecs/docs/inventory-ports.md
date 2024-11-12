## `wazuh-states-inventory-ports` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).
-   [Host Fields](https://www.elastic.co/guide/en/ecs/current/ecs-host.html).

|     | Field name  | ECS field name             | Data type | Description                                        |
| --- | ----------- | -------------------------- | --------- | -------------------------------------------------- |
|     | inode       | file.inode                 | keyword   | The unix inode of the port                         |
|     | item_id     | device.id                  | keyword   | Identifier of interface/protocol/address/port item |
|     | local_ip    | source.ip                  | ip        | Local IP address                                   |
|     | local_port  | source.port                | long      | Local port number                                  |
|     | pid         | process.pid                | long      | Process ID                                         |
|     | process     | process.name               | keyword   | Process name                                       |
|     | protocol    | network.protocol           | keyword   | Protocol used                                      |
|     | remote_ip   | destination.ip             | ip        | Remote IP address                                  |
|     | remote_port | destination.port           | long      | Remote port number                                 |
|     | scan_time   | @timestamp                 | date      | Timestamp of the scan                              |
| *   | rx_queue    | host.network.ingress.queue | long      | Receive queue length                               |
| *   | state       | interface.state            | keyword   | State of the network interface                     |
| *   | tx_queue    | host.network.egress.queue  | long      | Transmit queue length                              |

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
      id: {}
      groups: {}
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
