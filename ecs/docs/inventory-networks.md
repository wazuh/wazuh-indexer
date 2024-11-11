## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

|     | Field name  | ECS field name                   | Data type | Description                                                      |
| --- | ----------- | -------------------------------- | --------- | ---------------------------------------------------------------- |
|     | adapter     | observer.ingress.interface.alias | keyword   | Adapter name of the network interface                            |
|     | address     | host.ip                          | ip        | Network address                                                  |
|     | iface       | observer.ingress.interface.name  | keyword   | Name of the network interface                                    |
|     | item_id     | device.id                        | keyword   | Identifier of interface/protocol/address/port item               |
|     | mac         | host.mac                         | keyword   | MAC address of the network interface                             |
|     | name        | observer.ingress.interface.name  | keyword   | Name of the network interface                                    |
|     | proto       | network.protocol                 | keyword   | Type of network protocol                                         |
|     | rx_bytes    | host.network.ingress.bytes       | long      | Number of received bytes                                         |
|     | rx_packets  | host.network.ingress.packets     | long      | Number of received packets                                       |
|     | scan_time   | @timestamp                       | date      | Timestamp of the scan                                            |
|     | tx_bytes    | host.network.egress.bytes        | long      | Number of transmitted bytes                                      |
|     | tx_packets  | host.network.egress.packets      | long      | Number of transmitted packets                                    |
|     | type        | network.type                     | keyword   | IPv4 or IPv6 for protocols, interface type for interface records |
| *   | broadcast   | network.broadcast                | ip        | Broadcast address                                                |
| *   | dhcp        | network.dhcp                     | keyword   | DHCP status (enabled, disabled, unknown, BOOTP)                  |
| *   | gateway     | network.gateway                  | ip        | Gateway address                                                  |
| *   | metric      | network.metric                   | long      | Metric of the network protocol                                   |
| *   | mtu         | interface.mtu                    | long      | Maximum transmission unit size                                   |
| *   | netmask     | network.netmask                  | ip        | Network mask                                                     |
| *   | rx_dropped  | host.network.ingress.drops       | long      | Number of dropped received packets                               |
| *   | rx_errors   | host.network.ingress.errors      | long      | Number of reception errors                                       |
| *   | state       | interface.state                  | keyword   | State of the network interface                                   |
| *   | tx_dropped  | host.network.egress.drops        | long      | Number of dropped transmitted packets                            |
| *   | tx_errors   | host.network.egress.errors       | long      | Number of transmission errors                                    |
| *   | type        | interface.type                   | keyword   | Interface type (eg. "wireless" or "ethernet")                    |

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
      ip: {}
      mac: {}
      network:
        fields:
          egress:
            fields:
              bytes: {}
              packets: {}
          ingress:
            fields:
              bytes: {}
              packets: {}
  network:
    fields:
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
  process:
    fields:
      name: {}
      pid: {}
  source:
    fields:
      ip: {}
      port: {}
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
        "number_of_replicas": "0",
        "number_of_shards": "1",
        "query.default_field": [
          "agent.id",
          "agent.groups",
          "device.id",
          "event.id",
          "host.ip",
          "observer.ingress.interface.name",
          "observer.ingress.interface.alias",
          "process.name"
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
        "destination": {
          "properties": {
            "ip": {
              "type": "ip"
            },
            "port": {
              "type": "long"
            }
          }
        },
        "device": {
          "properties": {
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "file": {
          "properties": {
            "inode": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "host": {
          "properties": {
            "ip": {
              "type": "ip"
            },
            "mac": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "network": {
              "properties": {
                "egress": {
                  "properties": {
                    "bytes": {
                      "type": "long"
                    },
                    "packets": {
                      "type": "long"
                    }
                  }
                },
                "ingress": {
                  "properties": {
                    "bytes": {
                      "type": "long"
                    },
                    "packets": {
                      "type": "long"
                    }
                  }
                }
              }
            }
          }
        },
        "network": {
          "properties": {
            "protocol": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "type": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "observer": {
          "properties": {
            "ingress": {
              "properties": {
                "interface": {
                  "properties": {
                    "alias": {
                      "ignore_above": 1024,
                      "type": "keyword"
                    },
                    "name": {
                      "ignore_above": 1024,
                      "type": "keyword"
                    }
                  }
                }
              },
              "type": "object"
            }
          }
        },
        "process": {
          "properties": {
            "name": {
              "fields": {
                "text": {
                  "type": "match_only_text"
                }
              },
              "ignore_above": 1024,
              "type": "keyword"
            },
            "pid": {
              "type": "long"
            }
          }
        },
        "source": {
          "properties": {
            "ip": {
              "type": "ip"
            },
            "port": {
              "type": "long"
            }
          }
        }
      }
    }
  }
}

```
