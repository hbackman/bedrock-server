defmodule BedrockServer.Client.State do
  defstruct [
    connection_pid: nil,
    session_id: nil,

    # Compression Settings
    compression_enabled: false,
    compression_algorithm: nil,
  ]
end

defimpl RakNet.Client, for: BedrockServer.Client.State do
  def connect(%BedrockServer.Client.State{}, connection_pid, _) do
    state = %BedrockServer.Client.State{
      connection_pid: connection_pid,
      session_id: :rand.uniform(1000), # todo: make this unique
    }

    BedrockServer.Client.start(state)
    state
  end

  def receive(%BedrockServer.Client.State{session_id: id}, buffer) do
    BedrockServer.Client.recieve(id, buffer)
  end

  def disconnect(%BedrockServer.Client.State{session_id: id}) do
    BedrockServer.Client.disconnect(id)
  end
end

defmodule BedrockServer.Client do
  use GenServer

  alias BedrockServer.Client.State
  alias BedrockServer.Zlib
  alias BedrockServer.Packet

  require Logger

  @doc """
  Starts the client without linking.
  """
  def start(%State{} = state) do
    {:ok, pid} = GenServer.start(__MODULE__, state)

    Registry.register(__MODULE__, state.session_id, pid)
    {:ok, pid}
  end

  @doc """
  Handle a game packet.
  """
  def recieve(session_id, buffer) do
    case lookup(session_id) do
      nil -> nil
      pid -> GenServer.cast(pid, buffer)
    end
  end

  defp lookup(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{_, pid}] ->
        if Process.alive?(pid) do
          pid
        else
          Registry.unregister(__MODULE__, session_id)
          nil
        end
      _ ->
        nil
    end
  end

  @doc """
  Disconnect the client.
  """
  def disconnect(session_id) do
    Registry.unregister(__MODULE__, session_id)
  end

  # Log a message with the client prefixed.
  defp log(client, level, message) do
    Logger.log(level, "[BedrockServer] " <> message)
  end

  # ---------------------------------------------------------------------------
  # Server Implementation
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    {:ok, opts}
  end

  @impl GenServer
  def handle_cast(buffer, client) do
    packets = buffer
      |> inflate(client.compression_enabled, client.compression_algorithm)
      |> unbatch()

    client = Enum.reduce(packets, client, fn packet, client ->
      packet
        |> decode_packet()
        |> handle_packet(client)
    end)

    {:noreply, client}
  end

  defp handle_packet(%Packet{
    packet_id: :network_settings_request,
    packet_buf: _packet_buf
  }, client) do
    log(client, :debug, "Received :network_settings_request packet.")

    # | Field Name                | Type  |
    # |---------------------------|-------|
    # | Compression Threshold     | short |
    # | Compression Algorithm     | short |
    # | Client Throttling         | bool  |
    # | Client Throttle Threshold | byte  |
    # | Client Throttle Scalar    | float |

    message = <<>>
      <> Packet.encode_header(:network_settings, 0, 0)
      <> Packet.encode_ushort(1) # compress everything
      <> Packet.encode_ushort(0) # compress using zlib
      <> Packet.encode_bool(false) # Disable throttling
      <> Packet.encode_byte(0)
      <> Packet.encode_float(0)

    send_packet(client, message)

    %{client |
      compression_enabled: true,
      compression_algorithm: :zlib,
    }
  end

  defp handle_packet(%Packet{
    packet_id: :login,
    packet_buf: buffer,
  }, client) do
    log(client, :debug, "Received :login packet.")

    #{_, buffer} = Packet.decode_int(buffer)  # Protocol
    #
    ## Not sure why we need to do this.
    #{_, buffer} = Packet.decode_uvarint(buffer)
    #
    #{_, buffer} = Packet.decode_ascii(buffer) # Chain data
    #{_, buffer} = Packet.decode_ascii(buffer) # Skin data

    message = <<>>
      <> Packet.encode_header(:play_status)
      <> Packet.encode_int(6) # Login Success

    send_packet(client, message)

    # Resource Packs Info
    #
    # boolean :: Forced To Accept
    # boolean :: Scripting Enabled
    # ResourcePackInfo[] :: BehahaviorPackInfos
    # ResourcePackInfo[] :: ResourcePackInfos

    #message = <<>>
    #  <> <<Packet.to_binary(:resource_packs_info)::32-integer-little>>
    #  <> Packet.encode_bool(false)
    #  <> Packet.encode_bool(false)
    #  <> Packet.encode_byte(0)
    #  <> Packet.encode_byte(0)
#
    #send_packet(client, message)

    #message = <<>>
    #  <> Packet.encode_header(:resource_packs_info, 0, 0)
    #  <> Packet.encode_bool(false)

    # Disconnect
    #   Sent by the server to disconnect a client.
    #
    # boolean :: Hide disconnect screen
    # boolean :: Kick message

    # message = <<>>
    #   <> Packet.encode_header(:disconnect, 0, 0)
    #   <> Packet.encode_bool(false)
    #   <> Packet.encode_string("gtfo")
    #
    # send_packet(client, message)

    client
  end

  # Send a packet through RakNet.
  #
  defp send_packet(client, message, reliability \\ :reliable_ordered)
  defp send_packet(client, message, reliability) do
    message = message
      |> encode_batch()
      |> deflate(client.compression_enabled, client.compression_algorithm)

    message = <<0xfe>> <> message

    RakNet.Connection.send(client.connection_pid, reliability, message)
  end

  defp encode_batch(buffer),
    do: Packet.encode_batch(buffer)

  defp decode_packet(buffer),
    do: Packet.decode_packet(buffer)

  # Unpack a packet batch.
  #
  def unbatch(buf, packets \\ [])
  def unbatch("", packets),
    do: Enum.reverse(packets)

  def unbatch(buf, packets) do
    {str, buf} = Packet.decode_string(buf)
    unbatch(buf, [str | packets])
  end

  # De-compress a minecraft bedrock packet. Im not sure what other algorithms are
  # available, but right now it only supports zlib.
  #
  def inflate(buffer, compression_enabled, compression_algorithm) do
    if compression_enabled do
      case compression_algorithm do
        :zlib -> Zlib.inflate(buffer)
        _     -> buffer
      end
    else
      buffer
    end
  end

  def deflate(buffer, compression_enabled, compression_algorithm) do
    if compression_enabled do
      case compression_algorithm do
        :zlib -> Zlib.deflate(buffer)
        _     -> buffer
      end
    else
      buffer
    end
  end
end
