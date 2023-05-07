defmodule BedrockServer.Client.State do
  defstruct [
    connection_pid: nil,
    session_id: nil,
  ]
end

defimpl RakNet.Client, for: BedrockServer.Client.State do
  def connect(%BedrockServer.Client.State{}, connection_pid, _) do
    state = %BedrockServer.Client.State{
      connection_pid: connection_pid,
      session_id: :rand.uniform(1000), # todo: make this unique
    }

    BedrockServer.Client.start_link(state)
    state
  end

  def receive(%BedrockServer.Client.State{session_id: id}, packet_type, packet_buffer) do
    IO.inspect ["receive", id, packet_type, packet_buffer]
  end

  def disconnect(%BedrockServer.Client.State{session_id: id}) do
    IO.inspect ["disconnect", id]
  end
end

defmodule BedrockServer.Client do
  use GenServer

  alias BedrockServer.Client.State

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

end

#defmodule BedrockServer.Client do
#
#  alias BedrockServer.Packet
#
#  require Logger
#  import RakNet.Packet
#
#  def recieve(connection, _packet_type, packet_buffer) do
#    # Bedrock packets are batched, so decode the batch, then handle them each as
#    # separate packets.
#    Enum.each(decode_batch(packet_buffer), fn packet ->
#      <<
#        packet_id::id,
#        packet_buf::binary
#      >> = packet
#
#      handle(connection, Packet.to_atom(packet_id), packet_buf)
#    end)
#
#    connection
#  end
#
#  # Handles a :network_settings_request packet.
#  #
#  # This is the first packet sent in the game session. It contains the client's
#  # protocol version. The server is expected to respond to this with a network
#  # settings packet.
#  #
#  # | Field Name | Type | Notes               |
#  # |------------|------|---------------------|
#  # | Protocol   | _    | Not yet implemented |
#  #
#  defp handle(_connection, :network_setting_request, _buffer) do
#    Logger.debug("Received :network_settings_request")
#
#
#  end
#
#  defp handle(_connection, type, _) do
#    IO.inspect "Unhandled packet packet:"
#    IO.inspect type
#  end
#
#  defp decode_batch(buf, packets \\ [])
#  defp decode_batch("", packets),
#    do: Enum.reverse(packets)
#
#  defp decode_batch(buf, packets) do
#    {str, buf} = RakNet.Packet.decode_string(buf)
#    decode_batch(buf, [str | packets])
#  end
#
#  # Decode a bedrock packet. Bedrock uses zlib, so packets can be de-compressed using
#  # the erlang native :zlib module.
#  defp decode(packet) do
#    :zlib.uncompress(packet)
#  end
#
#  defp encode(packet) do
#    :zlib.compress(packet)
#  end
#
#end
