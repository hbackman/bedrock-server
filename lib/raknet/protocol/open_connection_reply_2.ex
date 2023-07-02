defmodule RakNet.Protocol.OpenConnectionReply2 do
  @moduledoc """
  | Field Name  | Type  | Notes                  |
  |-------------|-------|------------------------|
  | Packet ID   | i8    | 0x08                   |
  | Offline     | magic |                        |
  | Server ID   | i64   |                        |
  | Client Addr | addr  |                        |
  | MTU         | i16   |                        |
  | Encryption  | bool  | This is false for now. |
  """

  alias RakNet.Protocol.Packet

  @behaviour Packet

  import RakNet.Packet

  defstruct [
    :server_id,
    :client_host,
    :client_port,
    :mtu,
    :use_encryption,
  ]

  @impl Packet
  def packet_id(), do: :open_connection_reply_2

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end

  @impl Packet
  def encode(packet) do
    buffer = <<>>
      <> encode_msg(packet_id())
      <> offline()
      <> encode_int64(packet.server_id)
      <> encode_ip(4, packet.client_host, packet.client_port)
      <> encode_int16(packet.mtu)
      <> encode_bool(packet.use_encryption)
    {:ok, buffer}
  end

  @impl Packet
  def handle(%__MODULE__{}, connection) do
    {:ok, connection}
  end
end
