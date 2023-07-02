defmodule RakNet.Protocol.ConnectedPing do
  @moduledoc """
  | Field Name | Type | Notes                  |
  |------------|------|------------------------|
  | Packet ID  | i8   | 0x00                   |
  | Time       | i64  |                        |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
    :time,
  ]

  @impl Packet
  def packet_id(), do: :connected_ping

  @impl Packet
  def decode(buffer) do
    <<time::timestamp>> = buffer

    {:ok, %__MODULE__{
      time: time,
    }}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
