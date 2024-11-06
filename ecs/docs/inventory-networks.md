## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

|     | Field name  | ECS field name                  | Data type | Description                                        |
| --- | ----------- | ------------------------------- | --------- | -------------------------------------------------- |
|     | PID         | process.pid                     | INTEGER   | Process ID                                         |
|     | adapter     | observer.ingress.interface.name | KEYWORD   | Adapter name of the network interface              |
|     | address     | host.ip                         | KEYWORD   | Network address                                    |
|     | iface       | observer.ingress.interface.name | KEYWORD   | Name of the network interface                      |
|     | item_id     | device.id                       | KEYWORD   | Identifier of interface/protocol/address/port item |
|     | local_ip    | source.ip                       | KEYWORD   | Local IP address                                   |
|     | local_port  | source.port                     | INTEGER   | Local port number                                  |
|     | mac         | host.mac                        | KEYWORD   | MAC address of the network interface               |
|     | name        | observer.ingress.interface.name | KEYWORD   | Name of the network interface                      |
|     | process     | process.name                    | KEYWORD   | Process name                                       |
|     | protocol    | network.protocol                | KEYWORD   | Protocol used                                      |
|     | remote_ip   | destination.ip                  | KEYWORD   | Remote IP address                                  |
|     | remote_port | destination.port                | INTEGER   | Remote port number                                 |
|     | rx_bytes    | host.network.ingress.bytes      | INTEGER   | Number of received bytes                           |
|     | rx_errors   | host.network.ingress.errors     | INTEGER   | Number of reception errors                         |
|     | rx_packets  | host.network.ingress.packets    | INTEGER   | Number of received packets                         |
|     | scan_id     | event.id                        | KEYWORD   |                                                    |
|     | scan_id     | event.id                        | KEYWORD   | Reference to the scan information                  |
|     | scan_id     | event.id                        | KEYWORD   | Scan identifier                                    |
|     | scan_time   | @timestamp                      | DATE      | Timestamp of the scan                              |
|     | tx_bytes    | host.network.egress.bytes       | INTEGER   | Number of transmitted bytes                        |
|     | tx_errors   | host.network.egress.errors      | INTEGER   | Number of transmission errors                      |
|     | tx_packets  | host.network.egress.packets     | INTEGER   | Number of transmitted packets                      |
|     | type        | network.protocol                | KEYWORD   | Type of network protocol                           |

\* Custom fields

|     | Field name | ECS field name             | Data type | Description                                     |
| --- | ---------- | -------------------------- | --------- | ----------------------------------------------- |
| C   | broadcast  | network.broadcast          | KEYWORD   | Broadcast address                               |
| C   | checksum   | event.hash                 | KEYWORD   | Checksum of the scan                            |
| C   | dhcp       | network.dhcp               | KEYWORD   | DHCP status (enabled, disabled, unknown, BOOTP) |
| C   | gateway    | network.gateway            | KEYWORD   | Gateway address                                 |
| C   | metric     | network.metric             | INTEGER   | Metric of the network protocol                  |
| C   | mtu        | interface.mtu              | INTEGER   | Maximum transmission unit size                  |
| C   | netmask    | network.netmask            | KEYWORD   | Network mask                                    |
| C   | rx_dropped | host.network.ingress.drops | INTEGER   | Number of dropped received packets              |
| C   | rx_queue   | host.network.ingress.queue | INTEGER   | Receive queue length                            |
| C   | scan_id    | event.id                   | KEYWORD   | Reference to the scan information               |
| C   | state      | interface.state            | KEYWORD   | State of the connection                         |
| C   | state      | interface.state            | KEYWORD   | State of the network interface                  |
| C   | tx_dropped | host.network.egress.drops  | INTEGER   | Number of dropped transmitted packets           |
| C   | tx_queue   | host.network.egress.queue  | INTEGER   | Transmit queue length                           |

\* Pending fields

| Field name | ECS field name   | Notes                                |
| ---------- | ---------------- | ------------------------------------ |
| checksum   | event.hash       | Where is this checksum taken from?   |
| inode      | file.inode       | Where is the inode taken from?       |
| type       | network.type     | What are the possible values here?   |
| proto      | network.protocol | Possible duplicate of `protocol` |

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
