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

  def receive(%BedrockServer.Client.State{session_id: id}, packet_type, packet_buffer) do
    BedrockServer.Client.recieve(id, packet_type, packet_buffer)
  end

  def disconnect(%BedrockServer.Client.State{session_id: id}) do
    BedrockServer.Client.disconnect(id)
  end
end

defmodule BedrockServer.Client do
  use GenServer

  alias BedrockServer.Packet
  alias BedrockServer.Client.State

  import RakNet.Packet

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
  def recieve(session_id, _packet_type, packet_buffer) do
    case lookup(session_id) do
      nil -> nil
      pid ->
        # Bedrock packets are batched, so decode the batch, then handle them each as
        # separate packets.
        Enum.each(decode_batch(packet_buffer), fn packet ->
          <<
            packet_id::id,
            packet_buf::binary
          >> = packet

          GenServer.cast(pid, {Packet.to_atom(packet_id), packet_buf})
        end)
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

  # Handles a :network_settings_request packet.
  #
  # This is the first packet sent in the game session. It contains the client's
  # protocol version. The server is expected to respond to this with a network
  # settings packet.
  #
  # | Field Name | Type | Notes               |
  # |------------|------|---------------------|
  # | Protocol   | _    | Not yet implemented |
  #
  @impl GenServer
  def handle_cast({:network_setting_request, _packet_buffer}, client) do
    # | Field Name                | Type  |
    # |---------------------------|-------|
    # | Compression Threshold     | short |
    # | Compression Algorithm     | short |
    # | Client Throttling         | bool  |
    # | Client Throttle Threshold | byte  |
    # | Client Throttle Scalar    | float |

    message = <<>>
      <> Packet.encode_id(:network_settings)
      <> Packet.encode_short(1) # compress everything
      <> Packet.encode_short(1) # compress using zlib
      <> Packet.encode_bool(false) # Disable throttling
      <> Packet.encode_byte(0)
      <> Packet.encode_float(0)
      #|> Hexdump.inspect

    #RakNet.Connection.send(client.connection_pid, :unreliable, message)

    IO.inspect "HELLO"

    {:noreply, %{client |
      compression_enabled: true,
      compression_algorithm: :zlib,
    }}
  end

  defp decode_batch(buf, packets \\ [])
  defp decode_batch("", packets),
    do: Enum.reverse(packets)

  defp decode_batch(buf, packets) do
    {str, buf} = RakNet.Packet.decode_string(buf)
    decode_batch(buf, [str | packets])
  end

  # Decode a bedrock packet. Bedrock uses zlib, so packets can be de-compressed using
  # the erlang native :zlib module.
#  defp decode(packet) do
#    :zlib.uncompress(packet)
#  end
#
#  defp encode(packet) do
#    :zlib.compress(packet)
#  end
end
