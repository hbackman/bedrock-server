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
  defp log(_client, level, message) do
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

    settings = %BedrockServer.Protocol.NetworkSettings{
      compression_threshold: 1,
      compression_algorithm: 0,
    }

    send_packet(client, settings)

    %{client |
      compression_enabled: true,
      compression_algorithm: :zlib,
    }
  end

  defp handle_packet(%Packet{
    packet_id: :login,
    packet_buf: _buffer,
  }, client) do
    log(client, :debug, "Received :login packet.")

    # Send a login success message.

    status = %BedrockServer.Protocol.PlayStatus{
      status: :login_success,
    }

    send_packet(client, status)

    # Send Resource Packs Info and Resource Pack Stack. We do not care about
    # the responses for these so we can send them at the same time.

    send_packet(client, %BedrockServer.Protocol.ResourcePacksInfo{})
    send_packet(client, %BedrockServer.Protocol.ResourcePackStack{})

    # Disconnect

    kick = %BedrockServer.Protocol.Disconnect{
      hide_screen: false,
      kick_message: "gtfo",
    }

    send_packet(client, kick)

    client
  end

  defp handle_packet(%Packet{
    packet_id: :resource_packs_client_response,
    packet_buf: _buffer,
  }, client) do
    log(client, :debug, "Received :resource_packs_client_response.")

    # We do not do anything with this at the moment.

    client
  end

  defp handle_packet(%Packet{
    packet_id: :packet_violation_warning,
    packet_buf: _buffer,
  }, client) do
    log(client, :warn, "Received :packet_violation_warning")

    client
  end

  defp handle_packet(%Packet{
    packet_id: :client_cache_status,
    packet_buf: _buffer,
  }, client) do
    log(client, :debug, "Received :client_cache_status packet.")

    # The server does not support caching. Before I decide to implement this,
    # it might not be worth it. Because it is not supported on the switch.
    message = <<>>
      <> Packet.encode_header(:client_cache_status)
      <> Packet.encode_bool(false)

    send_packet(client, message)

    client
  end

  # Send a packet through RakNet.
  #
  defp send_packet(client, message, reliability \\ :reliable_ordered)
  defp send_packet(client, message, reliability) when is_binary(message) do
    message = message
      |> encode_batch()
      |> deflate(client.compression_enabled, client.compression_algorithm)

    message = <<0xfe>> <> message

    RakNet.Connection.send(client.connection_pid, reliability, message)

    client
  end

  # If the packet is passed instead of binary, then encode it and send it normally.
  #
  defp send_packet(client, %struct{} = message, reliability) do
    {:ok, buffer} = struct.encode(message)

    send_packet(client, buffer, reliability)
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
