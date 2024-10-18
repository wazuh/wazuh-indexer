### sys_netiface

|     | Field name | ECS field name      | Data type | Description                                      |
| --- | ---------- | ------------------- | --------- | ------------------------------------------------ |
|  x   | name       | network.name        | KEYWORD   | Name of the network interface                    |
|  ?  | adapter    |                     | KEYWORD   | Adapter name of the network interface            |
|  x   | type       | network.type        | KEYWORD   | Type of the network interface                    |
|  *   | state      | network.state       | KEYWORD   | State of the network interface                   |
|  *  | mtu        | network.mtu         | INTEGER   | Maximum transmission unit size                   |
|  x  | mac        | network.mac         | KEYWORD   | MAC address of the network interface             |
|     | tx_packets | network.out.packets | INTEGER   | Number of transmitted packets                    |
|     | rx_packets | network.in.packets  | INTEGER   | Number of received packets                       |
|     | tx_bytes   | network.out.bytes   | INTEGER   | Number of transmitted bytes                      |
|     | rx_bytes   | network.in.bytes    | INTEGER   | Number of received bytes                         |
|     | tx_errors  | network.out.errors  | INTEGER   | Number of transmission errors                    |
|     | rx_errors  | network.in.errors   | INTEGER   | Number of reception errors                       |
|     | tx_dropped | network.out.dropped | INTEGER   | Number of dropped transmitted packets            |
|     | rx_dropped | network.in.dropped  | INTEGER   | Number of dropped received packets               |
|  x   | item_id    |                     | KEYWORD   | Unique identifier for the network interface item |

### sys_netproto

|     | Field name | ECS field name      | Data type | Description                                     |
| --- | ---------- | ------------------- | --------- | ----------------------------------------------- |
|  r  | iface      | `sys_netiface.name` | KEYWORD   | Name of the network interface                   |
|     | type       | network.type        | KEYWORD   | Type of network protocol                        |
|     | gateway    | network.gateway     | KEYWORD   | Gateway address                                 |
|     | dhcp       | network.dhcp        | KEYWORD   | DHCP status (enabled, disabled, unknown, BOOTP) |
|     | metric     | network.metric      | INTEGER   | Metric of the network protocol                  |
|     | item_id    |                     | KEYWORD   | Unique identifier for the network protocol item |

### sys_netaddr

|     | Field name | ECS field name       | Data type | Description                                    |
| --- | ---------- | -------------------- | --------- | ---------------------------------------------- |
|  r  | iface      | `sys_netproto.iface` | KEYWORD   | Name of the network interface                  |
|     | proto      | `sys_netproto.type`  | KEYWORD   | Type of network protocol                       |
|     | address    | source.address       | KEYWORD   | Network address                                |
|     | netmask    | network.netmask      | KEYWORD   | Network mask                                   |
|     | broadcast  | network.broadcast    | KEYWORD   | Broadcast address                              |
|     | item_id    |                      | KEYWORD   | Unique identifier for the network address item |

### sys_ports

|     | Field name  | ECS field name       | Data type | Description                                 |
| --- | ----------- | -------------------- | --------- | ------------------------------------------- |
|     | protocol    | network.protocol     | KEYWORD   | Protocol used                               |
|     | local_ip    | source.ip            | KEYWORD   | Local IP address                            |
|     | local_port  | source.port          | INTEGER   | Local port number                           |
|     | remote_ip   | destination.ip       | KEYWORD   | Remote IP address                           |
|     | remote_port | destination.port     | INTEGER   | Remote port number                          |
|     | tx_queue    | network.out.queue    | INTEGER   | Transmit queue length                       |
|     | rx_queue    | network.in.queue     | INTEGER   | Receive queue length                        |
|     | inode       | system.network.inode | INTEGER   | Inode number                                |
|     | state       | network.transport    | KEYWORD   | State of the connection                     |
|     | PID         | process.pid          | INTEGER   | Process ID                                  |
|     | process     | process.name         | KEYWORD   | Process name                                |
|     | item_id     |                      | KEYWORD   | Unique identifier for the network port item |
