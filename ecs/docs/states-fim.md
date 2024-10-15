## `states-fim` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189377542

Based on ECS:

-   [File Fields](https://www.elastic.co/guide/en/ecs/current/ecs-file.html).
-   [Registry Fields](https://www.elastic.co/guide/en/ecs/current/ecs-registry.html).

| Field         | ECS field          | Type    | Description                                                      |
| ------------- | ------------------ | ------- | ---------------------------------------------------------------- |
|               | `agent.id`         | keyword | Agent's ID                                                       |
|               | \*`agent.groups`   | keyword | Agent's groups                                                   |
| arch          | \* ?               | keyword | Is arch a file property?                                         |
| attributes    | `file.attributes`  | keyword | Array of file attributes.                                        |
| file          | `file.name`        | keyword | Name of the file including the extension, without the directory. |
| full_path     | `file.path`        | keyword | Full path to the file, including the file name.                  |
| gid           | `file.gid`         | keyword | Primary group ID (GID) of the file.                              |
| gname         | `file.group`       | keyword | Primary group name of the file.                                  |
| inode         | `file.inode`       | keyword | Inode representing the file in the filesystem.                   |
| md5           | `file.hash.md5`    | keyword | MD5 hash of the file.                                            |
| mtime         | `file.mtime`       | date    | Last time the file's metadata changed.                           |
| perm          | `file.mode`        | keyword | File permissions in octal mode.                                  |
| sha1          | `file.hash.sha1`   | keyword | SHA1 hash of the file.                                           |
| sha256        | `file.hash.sha256` | keyword | SHA256 hash of the file.                                         |
| size          | `file.size`        | long    | File size in bytes.                                              |
| symbolic_path | `file.target_path` | keyword | Target path for symlinks.                                        |
| type          | `file.type`        | keyword | File type (file, dir, or symlink).                               |
| uid           | `file.uid`         | keyword | User ID (UID) of the file owner.                                 |
| uname         | `file.owner`       | keyword | File owner’s username.                                           |
| value_name    | `registry.key`     | keyword | Hive-relative path of keys.                                      |
| value_type    | `registry.value`   | keyword | Name of the value written.                                       |

\* Custom field

### ECS mapping

```yml
---
name: fim
fields:
    agent:
        fields:
            id: {}
            groups: {}
    file:
        fields:
            attributes: {}
            name: {}
            path: {}
            gid: {}
            group: {}
            inode: {}
            hash:
                fields:
                    md5: {}
                    sha1: {}
                    sha256: {}
            mtime: {}
            mode: {}
            size: {}
            target_path: {}
            type: {}
            uid: {}
            owner: {}
    registry:
        fields:
            key: {}
            value: {}
```

### Index settings

```json
{
    "index_patterns": ["wazuh-states-fim*"],
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
                    "file.name",
                    "file.path",
                    "file.target_path",
                    "file.group",
                    "file.uid",
                    "file.gid"
                ]
            }
        }
    }
}
```
