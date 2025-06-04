## `wazuh-states-fim-files` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh/issues/27898

Based on ECS:

- [File Fields](https://www.elastic.co/guide/en/ecs/current/ecs-file.html).

The detail of the fields can be found in csv file [States FIM files Fields](fields.csv).

### Transition table

| Field Name     | Type   | Description                                                               | Destination Field       | Custom |
|----------------|--------|---------------------------------------------------------------------------|-------------------------|--------|
| agent_id       | string | Unique identifier of the agent, e.g., "001".                              | agent.id                | FALSE  |
| agent_ip       | string | IP address of the agent.                                                  | agent.host.ip           | TRUE   |
| agent_name     | string | Name assigned to the agent.                                               | agent.name              | FALSE  |
| agent_version  | string | Version of the agent software, e.g., "v4.10.2".                           | agent.version           | FALSE  |
| arch           | string | Registry architecture type, e.g., "[x86]", "[x64]".                       | agent.host.architecture | TRUE   |
| cluster_name   | string | Wazuh cluster name                                                        | wazuh.cluster.name      | TRUE   |
| cluster_node   | string | Wazuh cluster node                                                        | wazuh.cluster.node      | TRUE   |
| gid            | string | Group ID associated with the entity.                                      | file.gid                | FALSE  |
| group_name     | string | Name of the group that owns the entity.                                   | file.group              | FALSE  |
| hash_md5       | string | MD5 hash of the file or registry value content.                           | file.hash.md5           | FALSE  |
| hash_sha1      | string | SHA-1 hash of the file or registry value content.                         | file.hash.sha1          | FALSE  |
| hash_sha256    | string | SHA-256 hash of the file or registry value content.                       | file.hash.sha256        | FALSE  |
| inode          | long   | Inode number (only applicable for file events).                           | file.inode              | FALSE  |
| mtime          | long   | Last modified timestamp of the entity.                                    | file.mtime              | FALSE  |
| path           | string | Absolute file path or full registry key path.                             | file.path               | FALSE  |
| schema_version | string | Wazuh schema version                                                      | wazuh.schema.version    | TRUE   |
| size           | long   | Size of the file or registry value (in bytes).                            | file.size               | FALSE  |
| timestamp      | long   | Timestamp when the event was generated.                                   | timestamp               | FALSE  |
| uid            | string | User ID associated with the entity.                                       | file.uid                | FALSE  |
| user_name      | string | Name of the owner of the entity (user).                                   | file.owner              | FALSE  |
