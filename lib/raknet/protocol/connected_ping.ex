defmodule RakNet.Protocol.ConnectedPing do
  @doc """
  | Field Name | Type | Notes                  |
  |------------|------|------------------------|
  | Packet ID  | i8   | 0x00                   |
  | Time       | i64  |                        |
  """

  alias RakNet.Protocol.Packet
  alias RakNet.Protocol.ConnectedPong

  @behaviour Packet

  import RakNet.Packet
  import RakNet.Connection,
    only: [enqueue: 3]

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
    {:ok, <<>>}
  end

  @impl Packet
  def handle(packet, connection) do
    {:ok, buffer} = %ConnectedPong{
      ping_time: packet.time,
      pong_time: RakNet.Server.timestamp(),
    } |> ConnectedPong.encode()

    {:ok, enqueue(connection, :unreliable, buffer)}
  end
end
