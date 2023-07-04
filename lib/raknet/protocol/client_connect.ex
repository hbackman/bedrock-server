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
  import RakNet.Packet

  @behaviour Packet

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
      client_id::64-integer,
      time::timestamp,
      security::8-integer,
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
    {:error, :not_implemented}
  end
end
