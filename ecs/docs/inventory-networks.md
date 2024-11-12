## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

|     | Field name                       | Data type | Description                                                                   | Example |
| --- | -------------------------------- | --------- | ----------------------------------------------------------------------------- | ------- |
|     | @timestamp                       | date      | Date/time when the event originated                                           |         |
|     | device.id                        | keyword   | The unique identifier of a device.                                            |         |
|     | host.ip                          | ip        | Host ip addresses                                                             |         |
|     | host.mac                         | keyword   | Host MAC addresses.                                                           |         |  |
|     | host.network.egress.bytes        | long      | The number of bytes sent on all network interfaces                            |         |
|     | host.network.egress.packets      | long      | The number of packets sent on all network interfaces                          |         |
|     | host.network.ingress.bytes       | long      | The number of bytes received on all network interfaces                        |         |
|     | host.network.ingress.packets     | long      | The number of packets received on all network interfaces                      |         |
|     | network.protocol                 | keyword   | Application protocol name                                                     |         |
|     | network.type                     | keyword   | In the OSI Model this would be the Network Layer. ipv4, ipv6, ipsec, pim, etc |         |
|     | observer.ingress.interface.alias | keyword   | Interface alias                                                               |         |
|     | observer.ingress.interface.name  | keyword   | Interface name                                                                |         |
| *   | host.network.egress.drops        | long      | Number of dropped transmitted packets                                         |         |
| *   | host.network.egress.errors       | long      | Number of transmission errors                                                 |         |
| *   | host.network.ingress.drops       | long      | Number of dropped received packets                                            |         |
| *   | host.network.ingress.errors      | long      | Number of reception errors                                                    |         |
| *   | interface.mtu                    | long      | Maximum transmission unit size                                                |         |
| *   | interface.state                  | keyword   | State of the network interface                                                |         |
| *   | interface.type                   | keyword   | Interface type (eg. "wireless" or "ethernet")                                 |         |
| *   | network.broadcast                | ip        | Broadcast address                                                             |         |
| *   | network.dhcp                     | keyword   | DHCP status (enabled, disabled, unknown, BOOTP)                               |         |
| *   | network.gateway                  | ip        | Gateway address                                                               |         |
| *   | network.metric                   | long      | Metric of the network protocol                                                |         |
| *   | network.netmask                  | ip        | Network mask                                                                  |         |

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
