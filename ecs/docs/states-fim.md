## `wazuh-states-fim` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-indexer/issues/282#issuecomment-2189377542

Based on ECS:

- [File Fields](https://www.elastic.co/guide/en/ecs/current/ecs-file.html).
- [Registry Fields](https://www.elastic.co/guide/en/ecs/current/ecs-registry.html).

|     | Field              | Type    | Description                                                                                           | Example                                                                                               |
| --- | ------------------ | ------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
|     | `agent.*`          | object  | All the agent fields.                                                                                 | `                                                                                                     |
|     | `file.attributes`  | keyword | Array of file attributes.                                                                             | `["readonly", "system"]`                                                                              |
|     | `file.gid`         | keyword | Primary group ID (GID) of the file.                                                                   | `1001`                                                                                                |
|     | `file.group`       | keyword | Primary group name of the file.                                                                       | `alice`                                                                                               |
|     | `file.inode`       | keyword | Inode representing the file in the filesystem.                                                        | `256383`                                                                                              |
|     | `file.name`        | keyword | Name of the file including the extension, without the directory.                                      | `example.png`                                                                                         |
|     | `file.mode`        | keyword | File permissions in octal mode.                                                                       | `0640`                                                                                                |
|     | `file.mtime`       | date    | Last time the file's metadata changed.                                                                |                                                                                                       |
|     | `file.owner`       | keyword | File owner’s username.                                                                                |                                                                                                       |
|     | `file.path`        | keyword | Full path to the file, including the file name. It should include the drive letter, when appropriate. | `/home/alice/example.png`                                                                             |
|     | `file.size`        | long    | File size in bytes.                                                                                   | `16384`                                                                                               |
|     | `file.target_path` | keyword | Target path for symlinks.                                                                             |                                                                                                       |
|     | `file.type`        | keyword | File type (file, dir, or symlink).                                                                    | `file`                                                                                                |
|     | `file.uid`         | keyword | User ID (UID) of the file owner.                                                                      | `1001`                                                                                                |
|     | `file.hash.md5`    | keyword | MD5 hash of the file.                                                                                 |                                                                                                       |
|     | `file.hash.sha1`   | keyword | SHA1 hash of the file.                                                                                |                                                                                                       |
|     | `file.hash.sha256` | keyword | SHA256 hash of the file.                                                                              |                                                                                                       |
|     | `registry.key`     | keyword | Hive-relative path of keys.                                                                           | `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\winword.exe`               |
|     | `registry.value`   | keyword | Name of the value written.                                                                            | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\winword.exe\Debugger` |

\* Custom field.

### ECS mapping

```yml
---
name: wazuh-states-fim
fields:
  base:
    fields:
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
