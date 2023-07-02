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
  alias RakNet.Server
  alias RakNet.Reliability

  import Packet

  require Logger
  require Packet

  @use_security 0

  @sync_ms 50
  @ping_ms 5000

  defmodule State do
    defstruct [
      host: {},
      port: nil,
      send: nil,
      server_identifier: nil,
      packet_buffer: [],
      packet_sequence: 0,
      message_index: 0,
      client_module: nil,
      client_data: %{},
      client: nil,
      # The :os.system_time(:millisecond) time at which we were created.
      base_time: 0,
      ordered_write_index: 0,
      # Sequencing for whole messages.
      send_sequence: 0,
      ack_buffer: [],
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
  def stop(connection_pid) do
    GenServer.stop(connection_pid, :shutdown)
  end

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

  # Log a message with the client prefixed.
  defp log(connection, level, message) do
    port = connection.port
    host = connection.host |> Server.ip_to_string()

    Logger.log(level, "[#{host}:#{port}] " <> message)
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
      |> sync_ack_buffer()
    }
  end

  @impl GenServer
  def handle_info(:ping, connection) do
    connection.send.(make_ping_buffer(connection.base_time))

    {:noreply, connection}
  end

  def enqueue(connection, reliability, buffer) when is_atom(reliability) and is_bitstring(buffer),
    do: enqueue(connection, reliability, [buffer])

  def enqueue(connection, reliability, buffers) when is_atom(reliability) and is_list(buffers) do
    num_buffers = length(buffers)
    new_buffers = buffers
      |> Enum.zip(0..(num_buffers - 1))
      |> Enum.map(fn {buffer, idx} ->
        %Reliability.Packet{
          reliability: reliability,
          message_buffer: buffer,
          message_index: if(Reliability.is_reliable?(reliability), do: connection.message_index, else: nil),
          order_index: connection.ordered_write_index,
          sequencing_index: connection.packet_sequence + idx,
        }
      end)

    %{ connection |
      packet_buffer: connection.packet_buffer ++ new_buffers,
      packet_sequence: connection.packet_sequence + num_buffers,
    }
  end

  defp sync_enqueued_packets(connection) do
    %{ packet_buffer: buffer } = connection

    if Enum.empty?(buffer) do
      connection
    else
      <<>>
        <> Packet.encode_msg(:data_packet_0)
        <> Packet.encode(buffer, connection.send_sequence)
        |> connection.send.()

      %{ connection |
        packet_buffer: [],
        send_sequence: connection.send_sequence + 1,
        message_index: connection.message_index + 1,
      }
    end
  end

  defp sync_ack_buffer(connection) do
    %{ ack_buffer: buffer } = connection

    buffer
      |> Enum.reverse()
      |> Enum.each(fn seq ->
      <<>>
        <> Packet.encode_msg(:ack)
        <> Packet.encode_int16(1)
        <> Packet.encode_int8(1)
        <> Packet.encode_seq_number(seq)
        |> connection.send.()
    end)

    %{ connection |
      ack_buffer: [],
    }
  end

  @impl GenServer
  def handle_cast({:send, reliability, message}, connection) do
    {:noreply, enqueue(connection, reliability, message)}
  end

  # Handles a :open_connection_request_1 message.
  #
  @impl GenServer
  def handle_cast({:open_connection_request_1, data}, connection) do
    log(connection, :debug, "Received open connection request 1")

    with {:ok, packet} <- RakNet.Protocol.OpenConnectionRequest1.decode(data),
         {:ok, result} <- RakNet.Protocol.OpenConnectionRequest1.handle(packet, connection)
    do
      {:noreply, result}
    else
      {:error, error} -> raise error
    end
  end

  # Handles a :open_connection_request_2 message.
  #
  @impl GenServer
  def handle_cast({:open_connection_request_2, data}, connection) do
    log(connection, :debug, "Received open connection request 2")

    with {:ok, packet} <- RakNet.Protocol.OpenConnectionRequest2.decode(data),
         {:ok, result} <- RakNet.Protocol.OpenConnectionRequest2.handle(packet, connection)
    do
      {:noreply, result}
    else
      {:error, error} -> raise error
    end
  end

  # Handles a :client_connect message.
  #
  @impl GenServer
  def handle_cast({:client_connect, data}, connection) do
    log(connection, :debug, "Received client connect")

    with {:ok, packet} <- RakNet.Protocol.ClientConnect.decode(data),
         {:ok, result} <- RakNet.Protocol.ClientConnect.handle(packet, connection)
    do
      {:noreply, result}
    else
      {:error, error} -> raise error
    end
  end

  # Handles a :client_handshake message.
  #
  # | Field Name    | Type | Notes                   |
  # |---------------|------|-------------------------|
  # | Server Addr   | addr |                         |
  # | Internal Addr | addr | Unknown what this does. |
  @impl GenServer
  def handle_cast({:client_handshake, data}, connection) do
    log(connection, :debug, "Received client handshake")

    addresses_length = bit_size(data) - 2 * 64

    <<
      _::bitstring-size(addresses_length),
      ping_time::timestamp,
      _pong_time::timestamp,
    >> = data

    # We should reply with a connected ping, then configure the server to ping the
    # client each 5 seconds.

    connection = enqueue(connection, :unreliable, [
      make_ping_buffer(connection.base_time),
      #make_pong_buffer(ping_time, connection.base_time),
    ])

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
    log(connection, :debug, "Received ack")

    # TODO: Implementation

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:nack, _data}, connection) do
    log(connection, :debug, "Received nack")

    # TODO: Implementation

    {:noreply, connection}
  end

  # Handles a :connected_ping by the client.
  @impl GenServer
  def handle_cast({:connected_ping, data}, connection) do
    log(connection, :debug, "Received connected ping")

    <<ping_time::size(64)>> = data

    message = make_pong_buffer(connection.base_time, ping_time)

    {:noreply, enqueue(connection, :unreliable, message)}
  end

  # Handles a :connected_pong by the client.
  @impl GenServer
  def handle_cast({:connected_pong, _}, connection) do
    {:noreply, connection}
  end

  # Handles a :client_disconnect message.
  #
  # | Field Name | Type | Notes |
  # |------------|------|-------|
  # | Packet ID  | i8   | 0x13  |
  @impl GenServer
  def handle_cast({:client_disconnect, _data}, connection) do
    log(connection, :debug, "Received client disconnect")

    Process.exit(self(), :normal)

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:game_packet, data}, connection) do
    log(connection, :debug, "Received game packet")

    # Forward the packet to the RakNet.Client implementation. This will now handle
    # all further game packets.
    RakNet.Client.receive(connection.client, :game_packet, data)

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({type, data}, connection) do
    log(connection, :debug, "Received #{type}")

    <<sequence::little-size(24), data::binary>> = data

    decoded = Packet.decode_packets(data)

    {:noreply, decoded
      |> Enum.reduce(connection, fn packet, conn ->
        {:noreply, conn} = handle_cast({packet.message_id, packet.message_buffer}, conn)
        conn
      end)
      |> buffer_ack(sequence)
    }
  end

  defp buffer_ack(connection, packet_index) when is_integer(packet_index) do
    %{connection | ack_buffer: [packet_index | connection.ack_buffer]}
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
