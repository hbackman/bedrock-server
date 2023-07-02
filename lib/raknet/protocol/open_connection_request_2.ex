defmodule RakNet.Protocol.OpenConnectionRequest2 do
  @doc """
  | Field Name  | Type  | Notes |
  |-------------|-------|-------|
  | Packet ID   | i8    | 0x07  |
  | Offline     | magic |       |
  | Server Addr | addr  |       |
  | MTU         | i16   |       |
  | Client ID   | i64   |       |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
    :mtu,
    :client_id
  ]

  @impl Packet
  def packet_id(), do: :open_connection_request_2

  @impl Packet
  def decode(buffer) do
    <<
      _::magic,
      _::ip(4),
      mtu::int16(),
      client_id::int64(),
    >> = buffer

    {:ok, %__MODULE__{
      mtu: mtu,
      client_id: client_id,
    }}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end
end
