## `wazuh-services` index data model

### Fields summary

The fields are based on https://github.com/wazuh/wazuh-agent/issues/807#issuecomment-3113217713

Based on osquery:

- [Windows services](https://osquery.io/schema/5.16.0/#services).
- [systemd_units](https://osquery.io/schema/5.16.0/#systemd_units).

The detail of the fields can be found in csv file [Services Fields](fields.csv).

### Transition table

| Field Name     | Type   | Description                                                               | Destination Field       | Custom |
|----------------|--------|---------------------------------------------------------------------------|-------------------------|--------|
| name           | text   | Service or unit name.                                                     | service.name            | FALSE  |
| display_name   | text   | Display name of the service or unit.                                      | service.display_name    | TRUE   |

... TO DO (deberíamos poner todos los campos como en [states-fim-files](../../states-fim-files/docs/README.md), o basta con linkar el comentario en el que vienen como en [users](../../states-inventory-users/docs/README.md)?) ...
