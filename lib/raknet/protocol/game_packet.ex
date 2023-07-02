defmodule RakNet.Protocol.GamePacket do
  alias RakNet.Protocol.Packet

  @behaviour Packet

  defstruct [
    :buffer,
  ]

  @impl Packet
  def packet_id(), do: :game_packet

  @impl Packet
  def decode(buffer) do
    {:ok, %__MODULE__{
      buffer: buffer,
    }}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
