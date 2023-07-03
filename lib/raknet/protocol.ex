defmodule RakNet.Protocol do

  require Logger

  import RakNet.Connection, only: [enqueue: 3]

  @packets [
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
    RakNet.Protocol.GamePacket,
  ]

  @doc """
  Resolve a packet from a given packet id.
  """
  def decode_packet(packet_id, buffer) do
    packet = Enum.find(@packets, fn h ->
      packet_id == h.packet_id()
    end)

    case packet do
      nil    -> {:error, :unknown_packet_id}
      packet -> packet.decode(buffer)
    end
  end

  # Log a message with the client prefixed.
  defp log(connection, level, message) do
    port = connection.port
    host = connection.host |> RakNet.Server.ip_to_string()

    Logger.log(level, "[#{host}:#{port}] " <> message)
  end

  def handle(%RakNet.Protocol.GamePacket{buffer: buffer}, connection) do
    log(connection, :debug, "Received GamePacket")

    # Forward the packet to the RakNet.Client implementation. This will now handle
    # all further game packets.
    RakNet.Client.receive(connection.client, buffer)

    {:ok, connection}
  end

  def handle(%RakNet.Protocol.Ack{}, connection) do
    log(connection, :debug, "Received ack")

    # TODO: Implementation

    {:ok, connection}
  end

  def handle(%RakNet.Protocol.Nack{}, connection) do
    log(connection, :debug, "Received nack")

    # TODO: Implementation

    {:ok, connection}
  end

  def handle(%RakNet.Protocol.OpenConnectionRequest1{}, connection) do
    log(connection, :debug, "Received OpenConnectionRequest1")

    {:ok, buffer} = %RakNet.Protocol.OpenConnectionReply1{
      server_id: connection.server_identifier,
      use_security: false,
      mtu: 1400
    } |> RakNet.Protocol.OpenConnectionReply1.encode()

    connection.send.(buffer)

    {:ok, connection}
  end

  def handle(%RakNet.Protocol.OpenConnectionRequest2{mtu: mtu}, connection) do
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

  def handle(%RakNet.Protocol.ClientConnect{time: time}, connection) do
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

  def handle(%RakNet.Protocol.ClientDisconnect{}, connection) do
    log(connection, :debug, "Received ClientDisconnect")

    # Notify the handler that the client has been disconnected.
    RakNet.Client.disconnect(connection.client)

    # Exit the connection.
    Process.exit(self(), :normal)

    {:ok, connection}
  end

  def handle(%RakNet.Protocol.NewIncomingConnection{}, connection) do
    log(connection, :debug, "Received NewIncomingConnection")

    client = RakNet.Client.connect(
      # The client protocol implementation wont recognize the module name as the
      # implementation type, so first we need to make it into a struct.
      struct(connection.client_module, %{}),
      self(),
      connection.client_data
    )

    {:ok, %{connection | client: client}}
  end

  def handle(%RakNet.Protocol.ConnectedPing{time: time}, connection) do
    log(connection, :debug, "Received ConnectedPing")

    {:ok, buffer} = %RakNet.Protocol.ConnectedPong{
      ping_time: time,
      pong_time: RakNet.Server.timestamp(),
    } |> RakNet.Protocol.ConnectedPong.encode()

    {:ok, enqueue(connection, :unreliable, buffer)}
  end

  def handle(%RakNet.Protocol.ConnectedPong{}, connection) do
    log(connection, :debug, "Received ConnectedPong")

    # Do nothing.

    {:ok, connection}
  end

end
