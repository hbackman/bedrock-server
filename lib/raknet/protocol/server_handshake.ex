defmodule RakNet.Protocol.ServerHandshake do
  @doc """
  | Field Name   | Type     | Notes                                            |
  |--------------|----------|--------------------------------------------------|
  | Packet ID    | i8       | 0x10                                             |
  | Client Addr  | addr     |                                                  |
  | System Index | i8       | Unknown what this does. Zero works.              |
  | Internal IDs | addr 10x | Unknown what this does. Empty ips seems to work. |
  | Request Time | i64      |                                                  |
  | Current Time | i64      |                                                  |
  """

  alias RakNet.Protocol.Packet
  import RakNet.Packet

  @behaviour Packet

  defstruct [
    :client_host,
    :client_port,
    # :system_index,
    :request_time,
    :current_time,
  ]

  @impl Packet
  def packet_id(), do: :server_handshake

  @impl Packet
  def decode(_buffer) do
    {:error, :not_implemented}
  end

  @impl Packet
  def encode(packet) do
    buffer = <<>>
      <> encode_msg(packet_id())
      <> encode_ip(4, packet.client_host, packet.client_port)
      <> encode_int16(0) # not sure what this does
      <> :erlang.list_to_binary(List.duplicate(
        encode_ip(4, {255, 255, 255, 255}, 19132), 10
      ))
      <> encode_timestamp(packet.request_time)
      <> encode_timestamp(packet.current_time)
    {:ok, buffer}
  end
end
