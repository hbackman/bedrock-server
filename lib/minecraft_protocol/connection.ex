defmodule BedrockProtocol.Connection do
  use GenServer, restart: :transient

  alias BedrockProtocol.Message
  alias BedrockProtocol.Packet
  alias BedrockProtocol.Reliability

  require Logger
  require Packet

  @use_security 0

  @sync_ms 10
  @ping_ms 5000

  defmodule State do
    defstruct [
      host: {},
      port: nil,
      send: nil,
      server_identifier: nil,
      packet_buffer: [],
      packet_sequence: 0,
    ]
  end

  def init(state) do
    {:ok, _} = :timer.send_interval(@sync_ms, :sync)
    {:ok, state}
  end

  @doc """
  Instantiate the connection.
  """
  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  @doc """
  Terminate the connection.
  """
  def stop(connection_pid), do: GenServer.stop(connection_pid, :shutdown)

  def handle_info(:sync, connection) do
    {:noreply, connection
      |> sync_enqueued_packets()
    }
  end

  def handle_info(:ping, connection) do

  end

  @doc """
  Handle a message from the client.
  """
  def handle_message(connection_pid, message_type, data) do
    GenServer.cast(connection_pid, {message_type, data})
  end

  defp enqueue(connection, reliability, buffer) when is_atom(reliability) and is_bitstring(buffer),
    do: enqueue(connection, reliability, [buffer])

  defp enqueue(connection, reliability, buffers) when is_atom(reliability) and is_list(buffers) do
    num_buffers = length(buffers)
    new_buffers = buffers
      |> Enum.zip(0..(num_buffers - 1))
      |> Enum.map(fn {buffer, idx} ->
        %Reliability.Packet{
          reliability: reliability,
          message_buffer: buffer,
          message_index: if(Reliability.is_reliable?(reliability), do: connection.message_index, else: nil),
        }
      end)

    %{ connection |
      packet_buffer: connection.packet_buffer ++ new_buffers,
      packet_sequence: connection.packet_sequence + num_buffers
    }
  end

  defp sync_enqueued_packets(connection) do
    IO.inspect "TEST"

    connection
  end

  # Handles a :open_connection_request_1 message.
  #
  # | Field Name       | Type  | Notes        |
  # |------------------|-------|--------------|
  # | Packet ID        | i8    | 0x06         |
  # | Offline          | magic |              |
  # | Protocol Version | i8    | Currently 11 |
  # | MTU              | null  | Null padding |
  def handle_cast({:open_connection_request_1, _data}, connection) do
    Logger.debug("Received open connection request 1")

    # | Field Name | Type  | Notes                    |
    # |------------|-------|--------------------------|
    # | Packet ID  | i8    | 0x06                     |
    # | Offline    | magic |                          |
    # | Server ID  | i64   |                          |
    # | Security   | bool  | This is false.           |
    # | MTU        | i16   | This is the MTU length.  |

    message = <<>>
      <> Packet.encode_msg(:open_connection_reply_1)
      <> Message.offline()
      <> connection.server_identifier
      <> Packet.encode_bool(false)
      <> Packet.encode_uint16(1400)
      |> Hexdump.inspect

    connection.send.(message)

    Logger.debug("Sent open connection reply 1")

    {:noreply, enqueue(connection, :unreliable_sequenced, message)}
  end

  # Handles a :open_connection_request_2 message.
  #
  # | Field Name  | Type  | Notes |
  # |-------------|-------|-------|
  # | Packet ID   | i8    | 0x07  |
  # | Offline     | magic |       |
  # | Server Addr | addr  |       |
  # | MTU         | i16   |       |
  # | Client ID   | i64   |       |
  def handle_cast({:open_connection_request_2, _data}, connection) do
    Logger.debug("Received open connection request 2")

    %{
      host: host,
      port: port,
    } = connection

    # | Field Name  | Type  | Notes                  |
    # |-------------|-------|------------------------|
    # | Packet ID   | i8    | 0x08                   |
    # | Offline     | magic |                        |
    # | Server ID   | i64   |                        |
    # | Client Addr | addr  |                        |
    # | MTU         | i16   |                        |
    # | Encryption  | bool  | This is false for now. |

    message = <<>>
      <> Message.binary(:open_connection_reply_2, true)
      <> Message.offline()
      <> connection.server_identifier
      <> Packet.encode_ip(4, host, port)
      <> Packet.encode_uint16(1400)
      <> Packet.encode_bool(false)
      |> Hexdump.inspect

    connection.send.(message)

    Logger.debug("Sent open connection reply 2")

    {:noreply, connection}
  end

  # Handles a :client_connect message.
  #
  # | Field Name | Type | Notes                  |
  # |------------|------|------------------------|
  # | Packet ID  | i8   | 0x09                   |
  # | GUID       | i64  | Not sure what this is. |
  # | Time       | i64  |                        |
  # | Security   | i8   | Not sure what this is. |
  # | Password   | ---- | Maybe related to ^     |
  def handle_cast({:client_connect, data}, connection) do
    Logger.debug("Received client connect")

    <<_client_id::size(64), time_sent::size(64), @use_security::size(8), _password::binary>> = data

    send_pong = BedrockServer.timestamp()

    %{
      host: host,
      port: port,
    } = connection

    # | Field Name   | Type     | Notes                                            |
    # |--------------|----------|--------------------------------------------------|
    # | Packet ID    | i8       | 0x10                                             |
    # | Client Addr  | addr     |                                                  |
    # | System Index | i8       | Unknown what this does. Zero works.              |
    # | Internal IDs | addr 10x | Unknown what this does. Empty ips seems to work. |
    # | Request Time | i64      |                                                  |
    # | Current Time | i64      |                                                  |

    message = <<>>
      <> Packet.encode_msg(:server_handshake)
      <> Packet.encode_ip(4, host, port)
      <> Packet.encode_uint8(0)
      <> :erlang.list_to_binary(List.duplicate(
        Packet.encode_ip(4, {255, 255, 255, 255}, 0), 10
      ))
      <> Packet.encode_timestamp(time_sent)
      <> Packet.encode_timestamp(send_pong)
      |> Packet.encode_encapsulated
      |> Hexdump.inspect

    connection.send.(message)

    Logger.debug("Sent server handshake")

    {:noreply, connection}
  end

  # Handles a :client_handshake message.
  #
  # | Field Name    | Type | Notes                   |
  # |---------------|------|-------------------------|
  # | Server Addr   | addr |                         |
  # | Internal Addr | addr | Unknown what this does. |
  def handle_cast({:client_handshake, _data}, connection) do
    Logger.debug("Received client handshake")

    # We do not need to respond to this. However, we should set the connection to
    # start pinging the client.

    {:ok, _} = :timer.send_interval(@ping_ms, :ping)

    {:noreply, connection}
  end

  def handle_cast({:ack, _data}, connection) do
    Logger.debug("Received ack")

    # TODO: Implementation

    {:noreply, connection}
  end

  def handle_cast({:nack, _data}, connection) do
    Logger.debug("Received nack")

    # TODO: Implementation

    {:noreply, connection}
  end

  # Handles a :connected_ping by the client.
  def handle_cast({:connected_ping, data}, connection) do
    Logger.debug("Received connected ping")

    <<_ping_time::size(64)>> = data

    # TODO

    {:noreply, connection}
  end

  # Handles a :client_disconnect message.
  #
  # | Field Name | Type | Notes |
  # |------------|------|-------|
  # | Packet ID  | i8   | 0x13  |
  def handle_cast({:client_disconnect, _data}, connection) do
    Logger.debug("Received client disconnect")

    Process.exit(self(), :normal)

    {:noreply, connection}
  end

  def handle_cast({:game_packet, _data}, connection) do
    Logger.debug("Received game packet")

    {:noreply, connection}
  end

  def handle_cast({:data_packet_4, data}, connection) do
    Logger.debug("Received client connect")

    <<_sequence::unsigned-size(24), data::binary>> = data

    connection = data
      |> Packet.decode_packets()
      |> Enum.reduce(connection, fn packet, conn ->
        {:noreply, conn} = handle_cast({packet.message_id, packet.message_buffer}, conn)
        conn
      end)

    {:noreply, connection}
  end

end
