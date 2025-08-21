## `wazuh-states-inventory-services` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-agent/issues/807#issuecomment-3113217713

Based on osquery and ECS:

- [services table (Windows)](https://osquery.io/schema/5.16.0/#services).
- [systemd_units table (Linux)](https://osquery.io/schema/5.16.0/#systemd_units).
- [Service fields](https://www.elastic.co/docs/reference/ecs/ecs-service).

Detailed information about the fields can be found in the [fields.csv](fields.csv) file.

### Transition table

| #   | Custom | ECS Field Name                          | Type      | Source                                                               | OS Availability         | Description                                                                      |
| --- | ------ | --------------------------------------- | --------- | -------------------------------------------------------------------- | ----------------------- | -------------------------------------------------------------------------------- |
| 1   | 0      | `service.id`                            | `text`    | `services.name` / `systemd_units.id` / `launchd.label`               | Windows / Linux / macOS | Service or unit name                                                             |
| 2   | 0      | `service.name`                          | `text`    | `services.display_name` / `launchd.name`                             | Windows / macOS         | Display name of the service or file name of plist                                |
| 3   | 1      | `service.description`                   | `text`    | `services.description` / `systemd_units.description`                 | Windows / Linux         | Description of the service/unit                                                  |
| 4   | 0      | `service.state`                         | `text`    | `services.status` / `systemd_units.active_state`  / `runtime`        | Windows / Linux / macOS | Current state: `RUNNING`, `STOPPED`, `active`, etc.                              |
| 5   | 1      | `service.sub_state`                     | `text`    | `systemd_units.sub_state`                                            | Linux                   | Low-level `systemd` substate                                                     |
| 6   | 1      | `service.start_type`                    | `text`    | `services.start_type` / `launchd.run_at_load`                        | Windows / macOS         | Start type: `AUTO_START`, `DEMAND_START`, `auto/manual` etc.                     |
| 7   | 0      | `service.type`                          | `text`    | `services.service_type`  / `launchd.process_type`                    | Windows / macOS         | Type of service: `OWN_PROCESS`, etc.                                             |
| 8   | 0      | `process.pid`                           | `long`    | `services.pid`  /      `runtime`                                     | Windows /macOS          | Process ID of the running service                                                |
| 9   | 1      | `service.exit_code`                     | `integer` | `services.service_exit_code`                                         | Windows                 | Service-specific exit code on failure                                            |
| 10  | 1      | `service.win32_exit_code`               | `integer` | `services.win32_exit_code`                                           | Windows                 | Win32 exit code on start/stop                                                    |
| 11  | 0      | `process.executable`                    | `text`    | `services.path` / `systemd_units.fragment_path`  / `launchd.program` | Windows / Linux / macOS | Path to the service executable or unit file                                      |
| 12  | 0      | `service.address`                       | `text`    | `services.module_path`                                               | Windows                 | Path to the service DLL (ServiceDll)                                             |
| 13  | 0      | `user.name`                             | `text`    | `services.user_account` / `systemd_units.user`                       | Windows / Linux         | User account running the service                                                 |
| 14  | 1      | `service.enabled`                       | `text`    | `systemd_units.unit_file_state` / `launchd.disabled`                 | Linux / macOS           | Whether the unit is enabled: `enabled`, `disabled`, etc.                         |
| 15  | 1      | `service.following`                     | `text`    | `systemd_units.following`                                            | Linux                   | Unit followed by this unit in `systemd`                                          |
| 16  | 1      | `service.object_path`                   | `text`    | `systemd_units.object_path`                                          | Linux                   | D-Bus object path of the unit                                                    |
| 17  | 0      | `service.target.ephemeral_id`           | `long`    | `systemd_units.job_id`                                               | Linux                   | Job ID assigned by `systemd`                                                     |
| 18  | 0      | `service.target.type`                   | `text`    | `systemd_units.job_type`                                             | Linux                   | Type of systemd job                                                              |
| 19  | 0      | `service.target.address`                | `text`    | `systemd_units.job_path`                                             | Linux                   | Path to job object                                                               |
| 20  | 0      | `file.path`                             | `text`    | `systemd_units.source_path` / `launchd.path`                         | Linux / macOS           | Path to the generated unit configuration file or to the `.plist` definition file |
| 21  | 0      | `process.args`                          | `text[]`  | `launchd.program_arguments`                                          | macOS                   | Command line arguments for the service                                           |
| 22  | 0      | `process.user.name`                     | `text`    |  `launchd.username`                                                  | macOS                   | User account running the job                                                     |
| 23  | 0      | `process.group.name`                    | `text`    | `launchd.groupname`                                                  | macOS                   | Group account running the job                                                    |
| 24  | 1      | `service.restart`                       | `text`    | `launchd.keep_alive`                                                 | macOS                   | Restart policy: always / on-failure / never                                      | 
| 25  | 1      | `service.frequency`                     | `long`    | `launchd.start_interval`                                             | macOS                   | Run frequency in seconds                                                         | 
| 26  | 0      | `log.file.path`                         | `text`    | `launchd.stdout_path`                                                | macOS                   | Redirect stdout to a file/pipe                                                   | 
| 27  | 1      | `error.log.file.path`                   | `text`    | `launchd.stderr_path`                                                | macOS                   | Redirect stderr to a file/pipe                                                   | 
| 28  | 0      | `process.working_directory`             | `text`    | `launchd.working_directory`                                          | macOS                   | Working directory of the job                                                     |
| 29  | 1      | `process.root_directory`                | `text`    | `launchd.root_directory`                                             | macOS                   | Chroot directory before execution                                                |
| 30  | 1      | `service.starts.on_mount`               | `boolean` |  `launchd.start_on_mount`                                            | macOS                   | Launches every time a filesystem is mounted                                      |
| 31  | 1      | `service.starts.on_path_modified`       | `text[]`  | `launchd.watch_paths`                                                | macOS                   | Launches on path modification                                                    |
| 32  | 1      | `service.starts.on_not_empty_directory` | `text[]`  | `launchd.queue_directories`                                          | macOS                   | Launches when directories become non-empty                                       |
| 33  | 1      | `service.inetd_compatibility`           | `boolean` | `launchd.inetd_compatibility`                                        | macOS                   | Run job as if launched from inetd                                                |

