# Bedrock Server

A Minecraft Bedrock server implementation in Elixir. This is experimental and is not
 a fully featured minecraft server (yet). Use at your own risk.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bedrock_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bedrock_server, "~> 0.1.0"}
  ]
end
```

---

### Todo

- [ ] ipv6

### Notes

Start an iex session with:

```console
iex -S mix
```

# RakNet

## Reliability

### Frame Set Packet

<table>
<tr>
  <th>Packet ID</th>
  <th colspan="3">Field Name</th>
  <th>Field Type</th>
  <th>Notes</th>
</tr>
<tr>
  <td rowspan="11">0x80..0x8d</td>
  <td colspan="3">Sequence number</td>
  <td>uint24le</td>
  <td></td>
</tr>
<tr>
  <td rowspan="10">Frames</td>
  <td colspan="2">Flags</td>
  <td>byte</td>
  <td>Top 3 bits are reliability type, fourth bit is 1 when the frame is fragmented and part of a compound.</td>
</tr>
<tr>
  <td colspan="2">Length IN BITS</td>
  <td>unsigned short</td>
  <td>Length of the body in bits.</td>
</tr>
<tr>
  <td colspan="2">Reliable frame index</td>
  <td>uint24le</td>
  <td>only if reliable</td>
</tr>
<tr>
  <td colspan="2">Sequenced frame index</td>
  <td>uint24le</td>
  <td>only if sequenced</td>
</tr>
<tr>
  <td rowspan="2">Order</td>
  <td>Ordered frame index</td>
  <td>uint24le</td>
  <td rowspan="2">only if ordered</td>
</tr>
<tr>
  <td>Order channel</td>
  <td>byte</td>
</tr>
<tr>
  <td rowspan="3">Fragment</td>
  <td>Compound size</td>
  <td>int</td>
  <td rowspan="3">only if fragmented</td>
</tr>
<tr>
  <td>Compound ID</td>
  <td>short</td>
</tr>
<tr>
  <td>Index</td>
  <td>int</td>
</tr>
<tr>
    <td>Body</td>
    <td>ceil(length/8) bytes</td>
  </tr>
</table>

## Handshake

1. C -> S: Open Connection Request 1
2. S -> C: Open Connection Reply 1
3. C -> S: Open Connection Request 2
4. S -> C: Open Connection Reply 2

Once the handshake is established, messages will be contained in a Frame Set Packet.

1. C -> S: Connection Request
2. S -> C: Connection Request Accepted
3. C -> S: New Incoming Connection

All following packets will be Game Packets.

## Types

| Name  | Size | Desc                                                                      |
|-------|------|---------------------------------------------------------------------------|
| addr  | 7    |                                                                           |
| int8  | 1    | Signed  8-bit integer                                                     |
| int16 | 2    | Signed 16-bit integer                                                     |
| int24 | 3    | Signed 24-bit integer                                                     |
| int64 | 4    | Signed 64-bit integer                                                     |
| MAGIC | 16   | 0x00ffff00fefefefefdfdfdfd12345678 This is hardcoded in the RakNet source |

## Packets

### Unconnected Ping `0x01`

Clients start by sending this packet to the server on port 19132 repeatedly for server
discovery. Once the client has established a connection, it will send connected pings
instead.

This packet should be replied to with an unconnected pong.
  
| Field    | Type  | Notes                            |
|----------|-------|----------------------------------|
| Ping ID  | i64   | Time since start in milliseconds |
| MAGIC    | MAGIC |                                  |


### Unconnected Ping `0x02`

Same as `0x01`, except for that it should only be replied to if there are any open
connections to the server.

### Unconnected Pong `0x1c`

| Field       | Type   | Notes                     |
|-------------|--------|---------------------------|
| Time        | i64    |                           |
| Server GUID | i64    |                           |
| MAGIC       | MAGIC  |                           |
| Server ID   | string | This is used for the MOTD |

**Server ID string format**  
The server id is seperated by semicolons and uses the following fields in order. Again,
joined by a semicolon.

| Field        | Desc                                               |
|--------------|----------------------------------------------------|
| Edition      | MCPE (Bedrock), MCEE (Education Edition)           |
| MOTD Line 1  | Server MOTD                                        |
| Protocol     | The protocol version number                        |
| Version      | The minecraft version number                       |
| Player Count | The number of connected players                    |
| Player Limit | The maximum number of players the server supports  |
| Server ID    | todo                                               |
| MOTD Line 2  | Server MOTD                                        |
| Gamemode     | The game mode string representation (seems unused) |
| Gamemode ID  | The game mode number representation (seems unused) |
| IPv4 Port    |                                                    |
| IPv6 Port    |                                                    |

### Connected Ping `0x00`

This packet should be replied to with a connected pong.

| Field       | Type   | Notes         |
|-------------|--------|---------------|
| Time        | i64    | The ping time |

### Connected Pong `0x03`

| Field     | Type   | Notes |
|-----------|--------|-------|
| Ping Time | i64    |       |
| Ping Time | i64    |       |

### Open Connection Request 1 `0x05`

The client will send this packet with decreasing MTU until the server responds. This
is done to discover the MTU size for the connection.

This packet should be replied to with Open Connection Reply 1 with the MTU size of the
amount of padding you received in bytes plus 46. (improve) (28 udp overhead, 1 packet 
id, 16 magic, 1 protocol version)

| Field            | Type         | Notes                                       |
|------------------|--------------|---------------------------------------------|
| MAGIC            | MAGIC        |                                             |
| Protocol Version | i8           | Currently 11                                |
| MTU              | Zero padding | Padding used to detect the maximum MTU size |

### Open Connection Reply 1 `0x06`

| Field        | Type    | Notes                         |
|--------------|---------|-------------------------------|
| MAGIC        | MAGIC   |                               |
| Server GUID  | i64     |                               |
| Use Security | boolean | This must be false            |
| MTU          | i16     | See Open Connection Request 1 |

### Open Connection Request 2 `0x07`

This packet should be replied to with Open Connection Reply 2.

| Field          | Type    | Notes                         |
|----------------|---------|-------------------------------|
| MAGIC          | MAGIC   |                               |
| Server Address | address |                               |
| MTU            | i16     | See Open Connection Request 1 |

### Open Connection Reply 2 `0x08`

| Field          | Type    | Notes                         |
|----------------|---------|-------------------------------|
| MAGIC          | MAGIC   |                               |
| Server GUID    | i64     |                               |
| MTU            | i16     | See Open Connection Request 1 |
| Use Encryption | boolean | Not sure what this does       |

### Connection Request `0x09`

This packet should be replied to with Connection Request Accepted.

| Field | Type |
|-------|------|
| GUID  | i64  |
| Time  | i64  |

### Connection Request Accepted `0x10`

| Field          | Type  | Notes                                                    |
|----------------|-------|----------------------------------------------------------|
| Client address | ip    |                                                          |
| System index   | int8  | Unknown what this does.                                  |
| Internal IDs   | ip*10 | Unknown what these do. Empty ipts for all of them works. |
| Request time   | int64 |                                                          |
| Time           | int64 |                                                          |

### New Incoming Connection `0x13`

| Field            | Type  | Notes                                                    |
|------------------|-------|----------------------------------------------------------|
| Server address   | ip    |                                                          |
| Internal address | int8  | Unknown what this does.                                  |

### Disconnect `0x15`

This packet is empty.