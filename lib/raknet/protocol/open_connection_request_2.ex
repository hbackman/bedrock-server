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
  alias RakNet.Protocol.OpenConnectionReply2

  @behaviour Packet

  import RakNet.Packet

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
      mtu_size::int16(),
      client_id::int64(),
    >> = buffer

    {:ok, %__MODULE__{
      mtu: mtu_size,
      client_id: client_id,
    }}
  end

  @impl Packet
  def encode(_packet) do
    {:error, :not_implemented}
  end

  @impl Packet
  def handle(packet, connection) do
    %{
      host: host,
      port: port,
    } = connection

    {:ok, buffer} = %OpenConnectionReply2{
      server_id: connection.server_identifier,
      client_host: host,
      client_port: port,
      mtu: packet.mtu,
      use_encryption: false,
    } |> OpenConnectionReply2.encode()

    connection.send.(buffer)

    {:ok, connection}
  end
end
