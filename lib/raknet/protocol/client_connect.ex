defmodule RakNet.Protocol.ClientConnect do
  @doc """
  | Field Name | Type | Notes                  |
  |------------|------|------------------------|
  | Packet ID  | i8   | 0x09                   |
  | Client ID  | i64  | Not sure what this is. |
  | Time       | i64  |                        |
  | Security   | i8   | Not sure what this is. |
  | Password   | ---- | Maybe related to ^     |
  """

  alias RakNet.Protocol.Packet
  alias RakNet.Protocol.ServerHandshake

  @behaviour Packet

  import RakNet.Packet
  import RakNet.Connection,
    only: [enqueue: 3]

  defstruct [
    :client_id,
    :time,
    :security,
    :password,
  ]

  @impl Packet
  def packet_id(), do: :client_connect

  @impl Packet
  def decode(buffer) do
    <<
      client_id::int64,
      time::timestamp,
      security::int8,
      password::binary
    >> = buffer

    # todo: decode timestamp

    {:ok, %__MODULE__{
      client_id: client_id,
      time: time,
      security: security,
      password: password,
    }}
  end

  @impl Packet
  def encode(_packet) do
    {:ok, <<>>}
  end

  @impl Packet
  def handle(packet, connection) do
    %{
      host: host,
      port: port,
    } = connection

    {:ok, buffer} = %ServerHandshake{
      client_host: host,
      client_port: port,
      request_time: packet.time,
      current_time: RakNet.Server.timestamp(),
    } |> ServerHandshake.encode()

    {:ok, enqueue(connection, :reliable_ordered, buffer)}
  end
end
