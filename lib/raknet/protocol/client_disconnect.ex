defmodule RakNet.Protocol.ClientDisconnect do
  @moduledoc """
  | Field Name | Type | Notes |
  |------------|------|-------|
  | Packet ID  | i8   | 0x13  |
  """

  alias RakNet.Protocol.Packet

  @behaviour Packet

  defstruct []

  @impl Packet
  def packet_id(), do: :client_disconnect

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
