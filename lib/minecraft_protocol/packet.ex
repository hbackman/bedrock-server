defmodule BedrockProtocol.Packet do

  alias BedrockProtocol.Message

  defstruct [
    :message_id,
    :message_time,
    message_data: "",
  ]

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """
  use Bitwise

  @doc """
  Construct a new packet.
  """
  def new(attributes \\ %{}) do
    struct(%__MODULE__{}, attributes)
  end

  @doc """
  Add data to the packet.
  """
  def add(packet, data) do
    Map.put(packet, :message_data, packet.message_data <> data)
  end

  @doc """
  Compiles the packet into a binary string.
  """
  def to_binary(packet) do
    message_head = <<
      Message.binary(packet.message_id),
      packet.message_time::size(64),
      Message.unique_id()::binary,
      Message.offline()::binary
    >>
    message_body = packet.message_data
    message_head <> message_body
  end

  @doc """
  Decodes a variable-size integer.
  """
  def decode_varint(data) do
    decode_varint(data, 0, 0)
  end

  defp decode_varint(<<1::1, value::7, rest::binary>>, num_read, acc) when num_read < 5 do
    decode_varint(rest, num_read + 1, acc + (value <<< (7 * num_read)))
  end

  defp decode_varint(<<0::1, value::7, rest::binary>>, num_read, acc) do
    result = acc + (value <<< (7 * num_read))
    <<result::32-signed>> = <<result::32-unsigned>>
    {result, rest}
  end

  defp decode_varint(_, num_read, _) when num_read >= 5, do: {:error, :too_long}
  defp decode_varint("", _, _), do: {:error, :too_short}

  @doc """
  Decodes a string.
  """
  def decode_string(data) do
    {strlen, data} = decode_varint(data)
    <<string::binary-size(strlen), rest::binary>> = data
    {string, rest}
  end

  @doc """
  Encodes a boolean.
  """
  def encode_bool(false), do: <<0>>
  def encode_bool(true),  do: <<1>>

  @doc """
  Encodes a variable-size integer.
  """
  def encode_varint(value) when value in -2_147_483_648..2_147_483_647 do
    <<value::32-unsigned>> = <<value::32-signed>>
    encode_varint(value, 0, "")
  end

  def encode_varint(_) do
    {:error, :too_large}
  end

  defp encode_varint(value, _, acc) when value <= 127 do
    <<acc::binary, 0::1, value::7>>
  end

  defp encode_varint(value, num_write, acc) when value > 127 and num_write < 5 do
    encode_varint(value >>> 7, num_write + 1, <<acc::binary, 1::1, band(value, 0x7F)::7>>)
  end

  @doc """
  Encodes a string.
  """
  def encode_string(string) do
    strlen = encode_varint(byte_size(string))
    <<strlen::binary, string::binary>>
  end

end