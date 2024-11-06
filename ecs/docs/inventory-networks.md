## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

|     | Field name  | ECS field name                   | Data type | Description                                                      |
| --- | ----------- | -------------------------------- | --------- | ---------------------------------------------------------------- |
|     | PID         | process.pid                      | long      | Process ID                                                       |
|     | adapter     | observer.ingress.interface.alias | keyword   | Adapter name of the network interface                            |
|     | address     | host.ip                          | ip        | Network address                                                  |
|     | iface       | observer.ingress.interface.name  | keyword   | Name of the network interface                                    |
|     | inode       | file.inode                       | keyword   | The unix inode of the port                                       |
|     | item_id     | device.id                        | keyword   | Identifier of interface/protocol/address/port item               |
|     | local_ip    | source.ip                        | ip        | Local IP address                                                 |
|     | local_port  | source.port                      | long      | Local port number                                                |
|     | mac         | host.mac                         | keyword   | MAC address of the network interface                             |
|     | name        | observer.ingress.interface.name  | keyword   | Name of the network interface                                    |
|     | process     | process.name                     | keyword   | Process name                                                     |
|     | proto       | network.protocol                 | keyword   | Type of network protocol                                         |
|     | protocol    | network.protocol                 | keyword   | Protocol used                                                    |
|     | protocol    | network.protocol                 | keyword   | Protocol used                                                    |
|     | remote_ip   | destination.ip                   | ip        | Remote IP address                                                |
|     | remote_port | destination.port                 | long      | Remote port number                                               |
|     | rx_bytes    | host.network.ingress.bytes       | long      | Number of received bytes                                         |
|     | rx_packets  | host.network.ingress.packets     | long      | Number of received packets                                       |
|     | scan_time   | @timestamp                       | date      | Timestamp of the scan                                            |
|     | tx_bytes    | host.network.egress.bytes        | long      | Number of transmitted bytes                                      |
|     | tx_packets  | host.network.egress.packets      | long      | Number of transmitted packets                                    |
|     | type        | network.type                     | keyword   | IPv4 or IPv6 for protocols, interface type for interface records |

\* Custom fields

|     | Field name | ECS field name              | Data type | Description                                     |
| --- | ---------- | --------------------------- | --------- | ----------------------------------------------- |
| C   | broadcast  | network.broadcast           | ip        | Broadcast address                               |
| C   | dhcp       | network.dhcp                | keyword   | DHCP status (enabled, disabled, unknown, BOOTP) |
| C   | gateway    | network.gateway             | ip        | Gateway address                                 |
| C   | metric     | network.metric              | long      | Metric of the network protocol                  |
| C   | mtu        | interface.mtu               | long      | Maximum transmission unit size                  |
| C   | netmask    | network.netmask             | ip        | Network mask                                    |
| C   | rx_dropped | host.network.ingress.drops  | long      | Number of dropped received packets              |
| C   | rx_errors  | host.network.ingress.errors | long      | Number of reception errors                      |
| C   | rx_queue   | host.network.ingress.queue  | long      | Receive queue length                            |
| C   | scan_id    | event.id                    | keyword   | Reference to the scan information               |
| C   | state      | interface.state             | keyword   | State of the network interface                  |
| C   | tx_dropped | host.network.egress.drops   | long      | Number of dropped transmitted packets           |
| C   | tx_errors  | host.network.egress.errors  | long      | Number of transmission errors                   |
| C   | tx_queue   | host.network.egress.queue   | long      | Transmit queue length                           |
| C   | type       | interface.type              | keyword   | Interface type (eg. "wireless" or "ethernet")   |

\* Pending fields

| Field name | ECS field name | Notes |
| ---------- | -------------- | ----- |
|            |                |       |

### ECS mapping

```yml
---
- name: wazuh-states-inventory-network
  fields:
      base:
          fields:
              "@timestamp": {}
      agent:
          fields:
              id: {}
              groups: {}
```

### Index settings

```json
{
    "index_patterns": ["wazuh-states-inventory-network*"],
    "priority": 1,
    "template": {
        "settings": {
            "index": {
                "number_of_shards": "1",
                "number_of_replicas": "0",
                "refresh_interval": "5s",
                "query.default_field": ["agent.id", "agent.groups"]
            }
        }
    }
}
```
