| Field Name    | Type   | Description                                                               | Destination Field       | Custom |
| ------------- | ------ | ------------------------------------------------------------------------- | ----------------------- | ------ |
| arch          | string | Registry architecture type, e.g., "[x86]", "[x64]".                       | agent.host.architecture | X      |
| agent_ip      | string | IP address of the agent.                                                  | agent.host.ip           | X      |
| agent_id      | string | Unique identifier of the agent, e.g., "001".                              | agent.id                |        |
| agent_name    | string | Name assigned to the agent.                                               | agent.name              |        |
| agent_version | string | Version of the agent software, e.g., "v4.10.2".                           | agent.version           |        |
| mode          | string | Monitoring mode, either "Scheduled" or "Realtime".                        | data_stream.type        |        |
| type          | string | Type of change detected, e.g., "added", "modified", "deleted".            | event.action            |        |
| type          | string | Type of monitored entity, e.g., "registry_value", "registry_key", "file". | event.category          |        |
| data_type     | string | Nature of the event, e.g., "event".                                       | event.type              |        |
| gid           | string | Group ID associated with the entity.                                      | file.gid                |        |
| group_name    | string | Name of the group that owns the entity.                                   | file.group              |        |
| hash_md5      | string | MD5 hash of the file or registry value content.                           | file.hash.md5           |        |
| hash_sha1     | string | SHA-1 hash of the file or registry value content.                         | file.hash.sha1          |        |
| hash_sha256   | string | SHA-256 hash of the file or registry value content.                       | file.hash.sha256        |        |
| inode         | long   | Inode number (only applicable for file events).                           | file.inode              |        |
| mtime         | long   | Last modified timestamp of the entity.                                    | file.mtime              |        |
| user_name     | string | Name of the owner of the entity (user).                                   | file.owner              |        |
| path          | string | Absolute file path or full registry key path.                             | file.path               |        |
| size          | long   | Size of the file or registry value (in bytes).                            | file.size               |        |
| uid           | string | User ID associated with the entity.                                       | file.uid                |        |
| value_type    | string | Type of the registry value, e.g., "REG_SZ", "REG_DWORD".                  | registry.data.type      |        |
| value_name    | string | Name of the registry value.                                               | registry.value          |        |
| timestamp     | long   | Timestamp when the event was generated.                                   | timestamp               |        |