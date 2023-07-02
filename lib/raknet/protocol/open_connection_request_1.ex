defmodule RakNet.Protocol.OpenConnectionRequest1 do
  @moduledoc """
  | Field Name       | Type    | Notes        |
  |------------------|---------|--------------|
  | Packet ID        | i8      | 0x06         |
  | Offline          | magic   |              |
  | Protocol Version | i8      | Currently 11 |
  | MTU              | padding | Zero padding |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
      :protocol,
      :mtu_size,
  ]

  @impl Packet
  def packet_id(), do: :open_connection_request_1

  @impl Packet
  def decode(buffer) do
    <<
      _::magic,
      protocol::int8,
      mtu_buf::binary
    >> = buffer

    mtu_size = byte_size(mtu_buf)

    {:ok, %__MODULE__{
      protocol: protocol,
      mtu_size: mtu_size,
    }}
  end

  @impl Packet
  def encode(packet) do
    buffer = <<>>
      <> encode_msg(packet_id())
      <> offline()
      <> encode_int8(packet.protocol)
      <> String.duplicate(<<0>>, packet.mtu_size)
    {:ok, buffer}
  end
end
