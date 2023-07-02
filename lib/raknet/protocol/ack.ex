defmodule RakNet.Protocol.Ack do
  alias RakNet.Protocol.Packet

  @behaviour Packet

  defstruct []

  @impl Packet
  def packet_id(), do: :ack

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
