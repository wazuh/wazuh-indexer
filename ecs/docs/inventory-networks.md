## `wazuh-states-inventory-networks` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

-   [Observer Fields](https://www.elastic.co/guide/en/ecs/current/ecs-observer.html).
-   [Interface Fields](https://www.elastic.co/guide/en/ecs/current/ecs-interface.html).
-   [Network Fields](https://www.elastic.co/guide/en/ecs/current/ecs-network.html).

| Field name       | ECS field name                              | Data type | Description           |
| ---------------- | ------------------------------------------- | --------- | --------------------- |
|                  | `agent.id`                                  | keyword   | Agent's ID            |
|                  | \*`agent.groups`                            | keyword   | Agent's groups        |
| scan_time        | `@timestamp`                                | date      | Timestamp of the scan |
| netiface.item_id | `observer.ingress.interface.id`             | keyword   | -                     |
| netiface.name    | `observer.ingress.interface.name`           | keyword   | -                     |
| netiface.type    | `observer.type`                             | keyword   | -                     |
| netiface.state   | \*`observer.ingress.interface.state`        | keyword   | -                     |
| netiface.mtu     | \*`observer.ingress.interface.mtu`          | keyword   | -                     |
| netiface.mac     | `observer.mac`                              | keyword   | -                     |



\* Custom field

\* Pending fields

-   netiface.adapter: duplicated by netiface.name ??

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
