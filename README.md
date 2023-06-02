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

### Notes

Start an iex session with:

```console
iex -S mix
```

Now, send messages to the UDP server from another terminal:

```console
echo "hello world" | nc -u -w0 0.0.0.0 19132
```

Now, try to send a quit message:

```console
echo "quit" | nc -u -w0 0.0.0.0 19132
```

Windows:
```console
ncat.exe -u 172.19.221.219 19132
```

# RakNet

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

| Name  | Desc                                                                      |
|-------|---------------------------------------------------------------------------|
| in64  |                                                                           |
| MAGIC | 0x00ffff00fefefefefdfdfdfd12345678 This is hardcoded in the RakNet source |

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

