## `wazuh-services` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-agent/issues/807#issuecomment-3113217713

Based on  and ECS:

- [services table (Windows)](https://osquery.io/schema/5.16.0/#services).
- [systemd_units table (Linux)](https://osquery.io/schema/5.16.0/#systemd_units).
- [Service fields](https://www.elastic.co/docs/reference/ecs/ecs-service).

Detailed information about the fields can be found in the [fields.csv](fields.csv) file.

### Transition table

| #   | Custom | ECS Field Name            | Type      | Source                                               | OS Availability | Description                                              |
| --- | ------ | ------------------------- | --------- | ---------------------------------------------------- | --------------- | -------------------------------------------------------- |
| 1   | 0      | `service.id`              | `text`    | `services.name` / `systemd_units.id`                 | Windows / Linux | Service or unit name                                     |
| 2   | 0      | `service.name`            | `text`    | `services.display_name`                              | Windows         | Display name of the service                              |
| 3   | 1      | `service.description`     | `text`    | `services.description` / `systemd_units.description` | Windows / Linux | Description of the service/unit                          |
| 4   | 0      | `service.state`           | `text`    | `services.status` / `systemd_units.active_state`     | Windows / Linux | Current state: `RUNNING`, `STOPPED`, `active`, etc.      |
| 5   | 1      | `service.sub_state`       | `text`    | `systemd_units.sub_state`                            | Linux           | Low-level `systemd` substate                             |
| 6   | 1      | `service.start_type`      | `text`    | `services.start_type`                                | Windows         | Start type: `AUTO_START`, `DEMAND_START`, etc.           |
| 7   | 0      | `service.type`            | `text`    | `services.service_type`                              | Windows         | Type of service: `OWN_PROCESS`, etc.                     |
| 8   | 0      | `process.pid`             | `long`    | `services.pid`                                       | Windows         | Process ID of the running service                        |
| 9   | 1      | `service.exit_code`       | `integer` | `services.service_exit_code`                         | Windows         | Service-specific exit code on failure                    |
| 10  | 1      | `service.win32_exit_code` | `integer` | `services.win32_exit_code`                           | Windows         | Win32 exit code on start/stop                            |
| 11  | 0      | `process.executable`      | `text`    | `services.path` / `systemd_units.fragment_path`      | Windows / Linux | Path to the service executable or unit file              |
| 12  | 0      | `service.address`         | `text`    | `services.module_path`                               | Windows         | Path to the service DLL (ServiceDll)                     |
| 13  | 0      | `user.name`               | `text`    | `services.user_account` / `systemd_units.user`       | Windows / Linux | User account running the service                         |
| 14  | 1      | `service.enabled`         | `text`    | `systemd_units.unit_file_state`                      | Linux           | Whether the unit is enabled: `enabled`, `disabled`, etc. |
| 15  | 1      | `service.following`       | `text`    | `systemd_units.following`                            | Linux           | Unit followed by this unit in `systemd`                  |
| 16  | 1      | `service.object_path`     | `text`    | `systemd_units.object_path`                          | Linux           | D-Bus object path of the unit                            |
| 17  | 1      | `service.job.id`          | `long`    | `systemd_units.job_id`                               | Linux           | Job ID for pending operations                            |
| 18  | 1      | `service.job.type`        | `text`    | `systemd_units.job_type`                             | Linux           | Type of systemd job                                      |
| 19  | 1      | `service.job.path`        | `text`    | `systemd_units.job_path`                             | Linux           | Path to job object                                       |
| 20  | 0      | `file.path`               | `text`    | `systemd_units.source_path`                          | Linux           | Path to the generated unit configuration file            |
