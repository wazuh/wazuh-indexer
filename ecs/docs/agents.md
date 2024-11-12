## `agents` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh/issues/23396#issuecomment-2176402993

Based on ECS [Agent Fields](https://www.elastic.co/guide/en/ecs/current/ecs-agent.html).

| Field             | ECS field              | Type    | Description                                                            |
| ----------------- | ---------------------- | ------- | ---------------------------------------------------------------------- |
| uuid              | `agent.id`             | keyword | Agent's ID                                                             |
| name              | `agent.name`           | keyword | Agent's name                                                           |
| groups            | \*`agent.groups`       | keyword | Agent's groups                                                         |
| internal_key      | \*`agent.key`          | keyword | Agent's registration key                                               |
| type              | `agent.type`           | keyword | Type of agent                                                          |
| version           | `agent.version`        | keyword | Agent's version                                                        |
| connection_status | \*`agent.is_connected` | boolean | Agents' interpreted connection status depending on `agent.last_login`  |
| last_keepalive    | \*`agent.last_login`   | date    | Agent's last login                                                     |
| ip                | `host.ip`              | ip      | Host IP addresses. Note: this field should contain an array of values. |
| os\_\*            | `host.os.full`         | keyword | Operating system name, including the version or code name.             |

\* Custom field

### ECS mapping

```yml
---
name: agent
fields:
  base:
    fields:
      tags: []
  agent:
    fields:
      id: {}
      name: {}
      type: {}
      version: {}
      groups: {}
      key: {}
      last_login: {}
      is_connected: {}
  host:
    fields:
      ip: {}
      os:
        fields:
          full: {}
```

```yml
---
---
- name: agent
  title: Wazuh Agents
  short: Wazuh Inc. custom fields.
  type: group
  group: 2
  fields:
    - name: groups
      type: keyword
      level: custom
      description: >
        The groups the agent belongs to.
    - name: key
      type: keyword
      level: custom
      description: >
        The agent's registration key.
    - name: last_login
      type: date
      level: custom
      description: >
        The agent's last login.
    - name: is_connected
      type: boolean
      level: custom
      description: >
        Agents' interpreted connection status depending on `agent.last_login`.

```

### Index settings

```json
{
    "index_patterns": [".agents*"],
    "priority": 1,
    "template": {
        "settings": {
            "index": {
                "hidden": true,
                "number_of_shards": "1",
                "number_of_replicas": "0",
                "refresh_interval": "5s",
                "query.default_field": [
                    "agent.id",
                    "agent.groups",
                    "agent.name",
                    "agent.type",
                    "agent.version",
                    "agent.name",
                    "host.os.full",
                    "host.ip"
                ]
            }
        }
    }
}
```
