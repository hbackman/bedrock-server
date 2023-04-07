defmodule BedrockProtocol.Connection do
  use GenServer, restart: :transient

  alias BedrockProtocol.Message
  alias BedrockProtocol.Packet

  require Logger
  require Packet

  @use_security 0

  defmodule State do
    defstruct [
      host: {},
      port: nil,
      send: nil,
      server_identifier: nil,
    ]
  end

  def init(state) do
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

  @doc """
  Send a message to the connection.
  """
  def send(connection_pid, message) do
    GenServer.cast(connection_pid, {:send, message})
    {:ok, nil}
  end

  @doc """
  Handle a message from the client.
  """
  def handle_message(connection_pid, message_type, data) do
    GenServer.cast(connection_pid, {message_type, data})
  end

  def handle_info(:send, message) do
    IO.inspect message
    {:noreply, nil}
  end

  def handle_cast({:open_connection_request_1, _data}, connection) do
    Logger.debug("Received open connection request 1")

    # RakNet Offline Message ID: Open Connection Reply 1 (0x06)
    # RakNet Offline Message Data ID: 00ffff00fefefefefdfdfdfd12345678
    # RakNet Server GUID: 8de7ee7941e6f2ce
    # RakNet Use encryption: false
    # RakNet MTU size: 1400

    message = <<>>
      <> Message.binary(:open_connection_reply_1, true)
      <> Message.offline()
      <> connection.server_identifier
      <> Packet.encode_bool(false)
      <> Packet.encode_uint16(1400)
      |> Hexdump.inspect

    connection.send.(message)

    Logger.debug("Sent open connection reply 1")

    {:noreply, connection}
  end

  def handle_cast({:open_connection_request_2, _data}, connection) do
    Logger.debug("Received open connection request 2")

    # RakNet Offline Message ID: Open Connection Reply 2 (0x08)
    # RakNet Offline Message Data ID
    # RakNet Server GUID
    # RakNet Client address:
    #   - IP Version: 4
    #   - Ipv4 Address: 127.0.0.1
    #   - Port: 56685
    # RakNet MTU size: 1400

    %{
      host: host,
      port: port,
    } = connection

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

  def handle_cast({:client_connect, data}, connection) do
    Logger.debug("Received client connect")

    <<_client_id::size(64), time_sent::size(64), @use_security::size(8), _password::binary>> = data

    send_pong = BedrockServer.timestamp()

    %{
      host: host,
      port: port,
    } = connection

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

  def handle_cast({:client_handshake, _data}, connection) do
    Logger.debug("Received client handshake")

    # Do nothing.

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

  def handle_cast({:data_packet_4, data}, connection) do
    Logger.debug("Received client connect")

    <<_sequence::unsigned-size(24), data::binary>> = data

    connection = data
      |> Packet.decode_packets()
      |> Enum.reduce(connection, fn {msg_id, msg_bf}, conn ->
        {:noreply, conn} = handle_cast({msg_id, msg_bf}, conn)
        conn
      end)

    #%{
    #  host: host,
    #  port: port,
    #} = connection
    #
    #empty_ip = Packet.encode_ip(4, {255, 255, 255, 255}, 0)
    #
    #message = <<>>
    #  <> Packet.encode_uint8(0x84)   # RakNet Packet type
    #  <> Packet.encode_seq_number(0) # RakNet Packet sequence
    #  <> Packet.encode_flag(0x60)    # RakNet Message flags
    #  <> Packet.encode_uint16(1856)  # RakNet Payload legth
    #  <> Packet.encode_uint24(0)     # RakNet Reliable message ordering: 0
    #  <> Packet.encode_uint24(0)     # RakNet Message ordering index
    #  <> Packet.encode_uint8(0)      # RakNet Message ordering channel
    #
    #message = message
    #  <> Packet.encode_msg(:server_handshake)
    #  <> Packet.encode_ip(4, host, port)
    #  <> :erlang.list_to_binary(List.duplicate(empty_ip, 9))
    #
    #connection.send.(message)

    {:noreply, connection}
  end

end
