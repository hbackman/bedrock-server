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

  alias BedrockServer.Packet
  alias BedrockServer.Client.State

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
    packet_id: :network_setting_request,
    packet_buf: _packet_buf
  }, client) do
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
      |> Packet.encode_batch()

    RakNet.Connection.send(client.connection_pid, :reliable_ordered, message)

    %{client |
      compression_enabled: true,
      compression_algorithm: :zlib,
    }
  end

  defp handle_packet(%Packet{
    packet_id: :login,
    packet_buf: buffer,
  }, client) do
    {protocol, buffer} = Packet.decode_int(buffer)
    IO.inspect protocol
    {chain_data, buffer} = Packet.decode_json(buffer)


    Hexdump.inspect chain_data

    client
  end

  defp decode_packet(buffer),
    do: Packet.decode_packet(buffer)

  defp unbatch(buf, packets \\ [])
  defp unbatch("", packets),
    do: Enum.reverse(packets)

  defp unbatch(buf, packets) do
    {str, buf} = RakNet.Packet.decode_string(buf)
    unbatch(buf, [str | packets])
  end

  # De-compress a minecraft bedrock packet. Im not sure what other algorithms are
  # available, but right now it only supports zlib.
  def inflate(buffer, compression_enabled, compression_algorithm) do
    if compression_enabled do
      case compression_algorithm do
        :zlib -> zlib_inflate(buffer)
        _     -> buffer
      end
    else
      buffer
    end
  end

  defp zlib_inflate(buffer) do
    z = :zlib.open()

    :zlib.inflateInit(z, -15)

    uncompressed = :zlib.inflate(z, buffer)

    :zlib.inflateEnd(z)

    uncompressed
      |> List.flatten()
      |> Enum.into(<<>>)
  end

  #defp zlib_deflate(buffer) do
  #  z = :zlib.open()
#
  #  :zlib.deflateInit(z, :default, :deflated, -15, 8, :default)
#
  #  [data] = :zlib.deflate(z, buffer, :finish)
#
  #  :zlib.deflateEnd(z)
#
  #  data
  #end

  #defp deflate(packet) do
  #  :zlib.compress(packet)
  #end
end
