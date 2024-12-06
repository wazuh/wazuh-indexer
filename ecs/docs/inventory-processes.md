## `wazuh-states-inventory-processes` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189837612

Based on ECS:

- [Process Fields](https://www.elastic.co/guide/en/ecs/current/ecs-process.html).

|    | Field name                      | Data type | Description                                                                                          | Examples                                           | Comments                                                   |
|----|---------------------------------| --------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------------- |
|    | `agent.*`                       | object    | All the agent fields.                                                                                | `                                                  |
|    | `@timestamp`                    | date      | Date/time when the event originated.                                                                 | `2016-05-23T08:05:34.853Z`                         |                                                            |
|    | `process.args`                  | keyword   | Array of process arguments.                                                                          | `["/usr/bin/ssh", "-l", "user", "10.0.0.16"]`      |                                                            |
|    | `process.command_line`          | wildcard  | process.command_line.                                                                                | `/usr/bin/ssh -l user 10.0.0.16`                   |                                                            |
|    | `process.name`                  | keyword   | Process name.                                                                                        | `ssh`                                              |                                                            |
|    | `process.parent.pid`            | long      | Parent process ID.                                                                                   | `4242`                                             |                                                            |
|    | `process.pid`                   | long      | Process ID.                                                                                          | `4242`                                             |                                                            |
|    | `process.real_group.id`         | keyword   | Unique identifier for the group on the system/platform.                                              |                                                    |                                                            |
|    | `process.real_user.id`          | keyword   | Unique identifier of the user.                                                                       | `S-1-5-21-202424912787-2692429404-2351956786-1000` |                                                            |
|    | `process.saved_group.id`        | keyword   | Unique identifier for the group on the system/platform.                                              |                                                    |                                                            |
|    | `process.saved_user.id`         | keyword   | Unique identifier of the user.                                                                       | `S-1-5-21-202424912787-2692429404-2351956786-1000` |                                                            |
|    | `process.start`                 | date      | The time the process started.                                                                        | `2016-05-23T08:05:34.853Z`                         |                                                            |
|    | `process.user.id`               | keyword   | Unique identifier of the user.                                                                       | `S-1-5-21-202424912787-2692429404-2351956786-1000` |                                                            |
| !  | `process.thread.id`             | long      | Thread ID.                                                                                           |                                                    | `thread.group` is **not part of ECS;** but `thread.id` is. |
|    | `process.tty.char_device.major` | object    | Information about the controlling TTY device. If set, the process belongs to an interactive session. |                                                    | Needs clarification                                        |
| \* | `process.group.id`              | keyword   | Unique identifier for the effective group on the system/platform.                                    |                                                    |                                                            |

\* Custom field

!: Fields awaiting analysis

<details><summary>Fields not included in ECS</summary>
<p>

|     | Field name | ECS field name            | Data type          | Description                                                                                          | Example | Comments                                                   |
| --- | ---------- | ------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------- | ------- | ---------------------------------------------------------- |
| x   | state      | `process.state`           | **No ECS mapping** | State of the process                                                                                 |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | utime      | `process.cpu.user`        | **No ECS mapping** | User mode CPU time                                                                                   |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | stime      | `process.cpu.system`      | **No ECS mapping** | Kernel mode CPU time                                                                                 |         | **Not part of ECS;** Maybe as a custom field.              |
| x?  | fgroup     | `process.group.file.id`   | **No ECS mapping** | unknown                                                                                              |         |                                                            |
| x   | priority   | `process.priority`        | **No ECS mapping** | Process priority                                                                                     |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | nice       | `process.nice`            | **No ECS mapping** | Nice value                                                                                           |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | size       | `process.size`            | **No ECS mapping** | Process size                                                                                         |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | vm_size    | `process.vm.size`         | **No ECS mapping** | Virtual memory size                                                                                  |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | resident   | `process.memory.resident` | **No ECS mapping** | Resident set size                                                                                    |         | **Not part of ECS;** Maybe as a custom field.              |
| x   | share      | `process.memory.share`    | **No ECS mapping** | Shared memory size                                                                                   |         | **Not part of ECS;** Maybe as a custom field.              |
| !   | pgrp       | `process.group.id`        | keyword            | Process group                                                                                        |         | Isn't it duplicated ??                                     |
| x   | session    | `process.session`         | **No ECS mapping** | Session ID                                                                                           |         | **Not part of ECS;** Needs clarification.                  |
| x   | nlwp       | `process.nlwp`            | **No ECS mapping** | Number of light-weight processes                                                                     |         | **Not part of ECS;** Needs clarification.                  |
| !   | tgid       | `process.thread.id`       | **No ECS mapping** | Thread ID ID                                                                                         |         | `thread.group` is **not part of ECS;** but `thread.id` is. |
| x   | processor  | `host.cpu.processor`      | **No ECS mapping** | Processor number                                                                                     |         | No ECS field refers to the core number of the CPU.         |

</p>
</details>

### ECS mapping

```yml
---
name: wazuh-states-inventory-processes
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
  process:
    fields:
      pid: {}
      name: ""
      parent:
        fields:
          pid: {}
      command_line: ""
      args: ""
      user:
        fields:
          id: ""
      real_user:
        fields:
          id: ""
      saved_user:
        fields:
          id: ""
      group:
        fields:
          id: ""
      real_group:
        fields:
          id: ""
      saved_group:
        fields:
          id: ""
      start: {}
      thread:
        fields:
          id: ""
      tty:
        fields:
          char_device:
            fields:
              major: ""
```

### Index settings

```json
{
  "index_patterns": ["wazuh-states-inventory-processes*"],
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
          "process.pid",
          "process.command_line"
        ]
      }
    }
  }
}
```
