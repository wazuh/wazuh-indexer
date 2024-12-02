## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
- [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
- [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

|     | Field name                         | Data type | Description                                                                    | Example                                |
| --- | ---------------------------------- | --------- | ------------------------------------------------------------------------------ | -------------------------------------- |
|     | `agent.*`                          | object    | All the agent fields.                                                          | `                                      |
|     | `@timestamp`                       | date      | Date/time when the event originated.                                           | `2016-05-23T08:05:34.853Z`             |
|     | `device.id`                        | keyword   | The unique identifier of a device.                                             | `00000000-54b3-e7c7-0000-000046bffd97` |
|     | `host.ip`                          | ip        | Host IP addresses. Note: this field should contain an array of values.         | `["192.168.56.11", "10.54.27.1"]`      |
|     | `host.mac`                         | keyword   | Host MAC addresses.                                                            |                                        |
|     | `host.network.egress.bytes`        | long      | The number of bytes sent on all network interfaces.                            |                                        |
|     | `host.network.egress.packets`      | long      | The number of packets sent on all network interfaces.                          |                                        |
|     | `host.network.ingress.bytes`       | long      | The number of bytes received on all network interfaces.                        |                                        |
|     | `host.network.ingress.packets`     | long      | The number of packets received on all network interfaces.                      |                                        |
|     | `network.protocol`                 | keyword   | Application protocol name.                                                     | `http`                                 |
|     | `network.type`                     | keyword   | In the OSI Model this would be the Network Layer. ipv4, ipv6, ipsec, pim, etc. | `ipv4`                                 |
|     | `observer.ingress.interface.alias` | keyword   | Interface alias.                                                               | `outside`                              |
|     | `observer.ingress.interface.name`  | keyword   | Interface name.                                                                | `eth0`                                 |
| \*  | `host.network.egress.drops`        | long      | Number of dropped transmitted packets.                                         |                                        |
| \*  | `host.network.egress.errors`       | long      | Number of transmission errors.                                                 |                                        |
| \*  | `host.network.ingress.drops`       | long      | Number of dropped received packets.                                            |                                        |
| \*  | `host.network.ingress.errors`      | long      | Number of reception errors.                                                    |                                        |
| \*  | `interface.mtu`                    | long      | Maximum transmission unit size.                                                |                                        |
| \*  | `interface.state`                  | keyword   | State of the network interface.                                                |                                        |
| \*  | `interface.type`                   | keyword   | Interface type (eg. "wireless" or "ethernet").                                 |                                        |
| \*  | `network.broadcast`                | ip        | Broadcast address.                                                             |                                        |
| \*  | `network.dhcp`                     | keyword   | DHCP status (enabled, disabled, unknown, BOOTP).                               |                                        |
| \*  | `network.gateway`                  | ip        | Gateway address.                                                               |                                        |
| \*  | `network.metric`                   | long      | Metric of the network protocol.                                                |                                        |
| \*  | `network.netmask`                  | ip        | Network mask.                                                                  |                                        |

\* Custom fields

### ECS mapping

```yml
---
name: wazuh-states-inventory-networks
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
  host:
    fields: "*"
  interface:
    fields:
      mtu: {}
      state: {}
      type: {}
  network:
    fields:
      broadcast: {}
      dhcp: {}
      gateway: {}
      metric: {}
      netmask: {}
      protocol: {}
      type: {}
  observer:
    fields:
      ingress:
        fields:
          interface:
            fields:
              alias: {}
              name: {}
```

### Index settings

```json
{
  "index_patterns": [
    "wazuh-states-inventory-networks*"
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
          "device.id",
          "event.id",
          "host.ip",
          "observer.ingress.interface.name",
          "observer.ingress.interface.alias",
          "process.name"
        ]
      }
    }
  }
}
```
