defmodule BedrockServer.Protocol.Disconnect do
  @moduledoc """
  | Field Name   | Type    | Notes          |
  |--------------|---------|----------------|
  | Packet ID    | 0x05    |                |
  | Hide Screen  | boolean |                |
  | Kick Message | string  |                |
  """

  defstruct [
    hide_screen: false,
    kick_message: nil
  ]

  import BedrockServer.Packet

  @doc """
  Encode a disconnect packet.
  """
  def encode(%__MODULE__{} = packet) do
    buffer = <<>>
      <> encode_header(:disconnect)
      <> encode_bool(packet.hide_screen)

    buffer = if packet.kick_message,
      do: buffer <> encode_string(packet.kick_message),
    else: buffer

    {:ok, buffer}
  end
end
