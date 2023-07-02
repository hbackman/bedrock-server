defmodule RakNet.Protocol.Nack do
  alias RakNet.Protocol.Packet

  @behaviour Packet

  defstruct []

  @impl Packet
  def packet_id(), do: :nack

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
