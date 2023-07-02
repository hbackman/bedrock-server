defmodule RakNet.Protocol.ConnectedPong do
  @doc """
  | Field Name | Type | Notes                  |
  |------------|------|------------------------|
  | Packet ID  | i8   | 0x03                   |
  | Ping Time  | i64  |                        |
  | Pong Time  | i64  |                        |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
    :ping_time,
    :pong_time,
  ]

  @impl Packet
  def packet_id(), do: :connected_pong

  @impl Packet
  def decode(_buffer) do
    {:error, :not_implemented}
  end

  @impl Packet
  def encode(packet) do
    buffer = <<>>
      <> encode_msg(packet_id())
      <> encode_timestamp(packet.ping_time)
      <> encode_timestamp(packet.pong_time)
    {:ok, buffer}
  end
end
