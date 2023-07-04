defmodule RakNet.Protocol.OpenConnectionReply1 do
  @moduledoc """
  | Field Name | Type  | Notes                    |
  |------------|-------|--------------------------|
  | Packet ID  | i8    | 0x06                     |
  | Offline    | magic |                          |
  | Server ID  | i64   |                          |
  | Security   | bool  | This is false.           |
  | MTU        | i16   | This is the MTU length.  |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
    :server_id,
    :use_security,
    :mtu,
  ]

  @impl Packet
  def packet_id(), do: :open_connection_reply_1

  @impl Packet
  def decode(buffer) do
    <<
      _::magic,
      server_id::64-integer,
      use_security::bool,
      mtu::16-integer
    >> = buffer

    use_security = decode_bool(use_security)

    {:ok, %__MODULE__{
      server_id: server_id,
      use_security: use_security,
      mtu: mtu,
    }}
  end

  @impl Packet
  def encode(packet) do
    buffer = <<>>
      <> encode_msg(packet_id())
      <> offline()
      <> encode_int64(packet.server_id)
      <> encode_bool(packet.use_security)
      <> encode_int16(packet.mtu)
    {:ok, buffer}
  end
end
