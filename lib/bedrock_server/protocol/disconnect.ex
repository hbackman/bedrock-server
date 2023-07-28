defmodule BedrockServer.Protocol.Disconnect do
  @moduledoc """
  | Field Name   | Type    | Notes          |
  |--------------|---------|----------------|
  | Packet ID    | 0x05    |                |
  | Hide Screen  | boolean |                |
  | Kick Message | string  |                |
  """

  alias BedrockServer.Protocol.Packet
  import BedrockServer.Packet

  @behaviour Packet

  defstruct [
    hide_screen: false,
    kick_message: nil
  ]

  @impl Packet
  def encode(%__MODULE__{} = packet) do
    buffer = <<>>
      <> encode_header(:disconnect)
      <> encode_bool(packet.hide_screen)

    buffer = if packet.kick_message,
      do: buffer <> encode_string(packet.kick_message),
    else: buffer

    {:ok, buffer}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end
end
