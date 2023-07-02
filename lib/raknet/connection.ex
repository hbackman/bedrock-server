defprotocol RakNet.Client do
  @doc """
  Handles a client connecting to the server. This should return the client after
  making any changes to it.
  """
  def connect(client, connection_pid, module_data)

  @doc """
  Handles an incoming game packet.
  """
  def receive(client, packet_buffer)

  @doc """
  Handles a client disconnecting from the server.
  """
  def disconnect(client)
end

defmodule RakNet.Connection do
  use GenServer, restart: :transient

  alias RakNet.Packet
  alias RakNet.Server
  alias RakNet.Reliability
  alias RakNet.Message

  require Logger
  require Packet

  @sync_ms 50
  @ping_ms 5000

  @handlers [
    RakNet.Protocol.Ack,
    RakNet.Protocol.Nack,
    RakNet.Protocol.ConnectedPing,
    RakNet.Protocol.ConnectedPong,
    RakNet.Protocol.OpenConnectionRequest1,
    RakNet.Protocol.OpenConnectionRequest2,
    RakNet.Protocol.OpenConnectionReply1,
    RakNet.Protocol.OpenConnectionReply2,
    RakNet.Protocol.ClientConnect,
    RakNet.Protocol.ServerHandshake,
    RakNet.Protocol.NewIncomingConnection,
    RakNet.Protocol.ClientDisconnect,
  ]

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
  def start(%State{} = state),
    do: GenServer.start(__MODULE__, state)

  @doc """
  Instantiate the connection.
  """
  def start_link(%State{} = state),
    do: GenServer.start_link(__MODULE__, state)

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

  # Log a message with the client prefixed.
  defp log(connection, level, message) do
    port = connection.port
    host = connection.host |> Server.ip_to_string()

    Logger.log(level, "[#{host}:#{port}] " <> message)
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
   # connection.send.(make_ping_buffer(connection.base_time))

   # {:ok, buffer} = %RakNet.Protocol.ConnectedPong{
   #   ping_time: time,
   #   pong_time: RakNet.Server.timestamp(),
   # } |> RakNet.Protocol.ConnectedPong.encode()

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:send, reliability, message}, connection) do
    {:noreply, enqueue(connection, reliability, message)}
  end

  defp handle(%RakNet.Protocol.GamePacket{buffer: buffer}, connection) do
    log(connection, :debug, "Received GamePacket")

    # Forward the packet to the RakNet.Client implementation. This will now handle
    # all further game packets.
    RakNet.Client.receive(connection.client, buffer)

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.Ack{}, connection) do
    log(connection, :debug, "Received ack")

    # TODO: Implementation

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.Nack{}, connection) do
    log(connection, :debug, "Received nack")

    # TODO: Implementation

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.OpenConnectionRequest1{}, connection) do
    log(connection, :debug, "Received OpenConnectionRequest1")

    {:ok, buffer} = %RakNet.Protocol.OpenConnectionReply1{
      server_guid: connection.server_identifier,
      use_security: false,
      mtu: 1400
    } |> RakNet.Protocol.OpenConnectionReply1.encode()

    connection.send.(buffer)

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.OpenConnectionRequest2{mtu: mtu}, connection) do
    log(connection, :debug, "Received OpenConnectionRequest2")

    %{
      host: host,
      port: port,
    } = connection

    {:ok, buffer} = %RakNet.Protocol.OpenConnectionReply2{
      server_id: connection.server_identifier,
      client_host: host,
      client_port: port,
      mtu: mtu,
      use_encryption: false,
    } |> RakNet.Protocol.OpenConnectionReply2.encode()

    connection.send.(buffer)

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.ClientConnect{time: time}, connection) do
    log(connection, :debug, "Received ClientConnect")

    %{
      host: host,
      port: port,
    } = connection

    {:ok, buffer} = %RakNet.Protocol.ServerHandshake{
      client_host: host,
      client_port: port,
      request_time: time,
      current_time: RakNet.Server.timestamp(),
    } |> RakNet.Protocol.ServerHandshake.encode()

    {:ok, enqueue(connection, :unreliable, buffer)}
  end

  defp handle(%RakNet.Protocol.ClientDisconnect{}, connection) do
    log(connection, :debug, "Received ClientDisconnect")

    # Notify the handler that the client has been disconnected.
    RakNet.Client.disconnect(connection.client)

    # Exit the connection.
    Process.exit(self(), :normal)

    {:ok, connection}
  end

  defp handle(%RakNet.Protocol.NewIncomingConnection{}, connection) do
    log(connection, :debug, "Received NewIncomingConnection")

    {:ok, _} = :timer.send_interval(@ping_ms, :ping)

    client = RakNet.Client.connect(
      # The client protocol implementation wont recognize the module name as the
      # implementation type, so first we need to make it into a struct.
      struct(connection.client_module, %{}),
      self(),
      connection.client_data
    )

    {:ok, %{connection | client: client}}
  end

  defp handle(%RakNet.Protocol.ConnectedPing{time: time}, connection) do
    log(connection, :debug, "Received ConnectedPing")

    {:ok, buffer} = %RakNet.Protocol.ConnectedPong{
      ping_time: time,
      pong_time: RakNet.Server.timestamp(),
    } |> RakNet.Protocol.ConnectedPong.encode()

    {:ok, enqueue(connection, :unreliable, buffer)}
  end

  defp handle(%RakNet.Protocol.ConnectedPong{}, connection) do
    log(connection, :debug, "Received ConnectedPong")

    # Do nothing.

    {:ok, connection}
  end

  @impl GenServer
  def handle_cast({message_type, data}, connection) do
    if Message.data_packet?(message_type) do
      <<sequence::little-size(24), data::binary>> = data

      encapsulated = Packet.decode_packets(data)

      {:noreply, encapsulated
        |> Enum.reduce(connection, fn packet, conn ->
          {:noreply, conn} = handle_cast({packet.message_id, packet.message_buffer}, conn)
          conn
        end)
        |> buffer_ack(sequence)
      }
    else
      case handle_packet(message_type, data, connection) do
        {:ok, connection} ->
          {:noreply, connection}

        {:error, _} ->
          Logger.error("Unknown message #{message_type}")

          {:noreply, connection}
      end
    end
  end

  defp handle_packet(message_id, message, connection) do
    case decode_packet(message_id, message) do
      {:ok, packet} ->
        handle(packet, connection)

      {:error, _} ->
        raise "Unknown message #{message_id}"
    end
  end

  # Find a packet by its message id.
  #
  defp decode_packet(message_id, message) do
    packet = Enum.find(@handlers, fn h ->
      message_id == h.packet_id()
    end)

    case packet do
      nil    -> {:error, :unknown_packet_id}
      packet -> packet.decode(message)
    end
  end

  defp buffer_ack(connection, packet_index) when is_integer(packet_index) do
    %{connection | ack_buffer: [packet_index | connection.ack_buffer]}
  end

end
