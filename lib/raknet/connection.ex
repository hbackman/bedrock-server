defprotocol RakNet.Client do
  @doc """
  Handles a client connecting to the server. This should return the client after
  making any changes to it.
  """
  def connect(client, connection_pid, module_data)

  @doc """
  Handles an incoming game packet.
  """
  def receive(client, packet_type, packet_buffer)

  @doc """
  Handles a client disconnecting from the server.
  """
  def disconnect(client)
end

defmodule RakNet.Connection do
  use GenServer, restart: :transient

  alias RakNet.Message
  alias RakNet.Packet
  alias RakNet.Reliability

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
      client_module: nil,
      client_data: %{},
      client: nil,
      # The :os.system_time(:millisecond) time at which we were created.
      base_time: 0,
    ]
  end

  @doc """
  Starts the connection without linking.
  """
  def start(%State{} = state) do
    GenServer.start(__MODULE__, state)
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
  def stop(connection_pid),
    do: GenServer.stop(connection_pid, :shutdown)

  @doc """
  Send a message to the client.
  """
  def send(connection_pid, reliability, message)

  def send(connection_pid, reliability, message) when is_bitstring(message) and is_atom(reliability) do
    GenServer.cast(connection_pid, {:send, reliability, message})
    {:ok, nil}
  end

  @doc """
  Handle a message from the client.
  """
  def handle_message(connection_pid, message_type, data) do
    GenServer.cast(connection_pid, {message_type, data})
  end

  # ---------------------------------------------------------------------------
  # Server Implementation
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(state) do
    {:ok, _} = :timer.send_interval(@sync_ms, :sync)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:sync, connection) do
    {:noreply, connection
      |> sync_enqueued_packets()
    }
  end

  @impl GenServer
  def handle_info(:ping, connection) do
    connection.send.(make_ping_buffer(connection.base_time))

    {:noreply, connection}
  end

  defp enqueue(connection, reliability, buffer) when is_atom(reliability) and is_bitstring(buffer),
    do: enqueue(connection, reliability, [buffer])

  defp enqueue(connection, reliability, buffers) when is_atom(reliability) and is_list(buffers) do
    num_buffers = length(buffers)
    new_buffers = buffers
      |> Enum.zip(0..(num_buffers - 1))
      |> Enum.map(fn {buffer, _idx} ->
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
    %{ packet_buffer: buffer } = connection

    Enum.each(buffer, fn packet ->
      # TODO: Encode packet properly
      connection.send.(packet.message_buffer)
    end)

    %{ connection |
      packet_buffer: [],
    }
  end

  @impl GenServer
  def handle_cast({:send, reliability, message}, connection) do
    {:noreply, enqueue(connection, reliability, message)}
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

    Logger.debug("Sending open connection reply 1")

    {:noreply, enqueue(connection, :unreliable, message)}
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
  @impl GenServer
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

    Logger.debug("Sending open connection reply 2")

    {:noreply, enqueue(connection, :unreliable, message)}
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
  @impl GenServer
  def handle_cast({:client_connect, data}, connection) do
    Logger.debug("Received client connect")

    <<_client_id::size(64), time_sent::size(64), @use_security::size(8), _password::binary>> = data

    send_pong = RakNet.Server.timestamp()

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

    Logger.debug("Sent server handshake")

    {:noreply, enqueue(connection, :unreliable, message)}
  end

  # Handles a :client_handshake message.
  #
  # | Field Name    | Type | Notes                   |
  # |---------------|------|-------------------------|
  # | Server Addr   | addr |                         |
  # | Internal Addr | addr | Unknown what this does. |
  @impl GenServer
  def handle_cast({:client_handshake, _data}, connection) do
    Logger.debug("Received client handshake")

    # We do not need to respond to this. However, we should set the connection to
    # start pinging the client.

    {:ok, _} = :timer.send_interval(@ping_ms, :ping)

    client = RakNet.Client.connect(
      # The client protocol implementation wont recognize the module name as the
      # implementation type, so first we need to make it into a struct.
      struct(connection.client_module, %{}),
      self(),
      connection.client_data
    )

    {:noreply, %{connection | client: client }}
  end

  @impl GenServer
  def handle_cast({:ack, _data}, connection) do
    Logger.debug("Received ack")

    # TODO: Implementation

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:nack, _data}, connection) do
    Logger.debug("Received nack")

    # TODO: Implementation

    {:noreply, connection}
  end

  # Handles a :connected_ping by the client.
  @impl GenServer
  def handle_cast({:connected_ping, data}, connection) do
    Logger.debug("Received connected ping")

    <<ping_time::size(64)>> = data

    connection.send.(make_pong_buffer(connection.base_time, ping_time))

    {:noreply, connection}
  end

  # Handles a :client_disconnect message.
  #
  # | Field Name | Type | Notes |
  # |------------|------|-------|
  # | Packet ID  | i8   | 0x13  |
  @impl GenServer
  def handle_cast({:client_disconnect, _data}, connection) do
    Logger.debug("Received client disconnect")

    Process.exit(self(), :normal)

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:game_packet, data}, connection) do
    Logger.debug("Received game packet")

    # Forward the packet to the RakNet.Client implementation. This will now handle
    # all further game packets.
    RakNet.Client.receive(connection.client, :game_packet, data)

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({_, data}, connection) do
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

  defp make_ping_buffer(base_time) do
    <<>>
      <> Packet.encode_msg(:connected_ping)
      <> Packet.encode_timestamp(RakNet.Server.timestamp(base_time))
  end

  defp make_pong_buffer(base_time, ping_time) do
    <<>>
      <> Packet.encode_msg(:connected_pong)
      <> Packet.encode_timestamp(ping_time)
      <> Packet.encode_timestamp(RakNet.Server.timestamp(base_time))
  end

end
