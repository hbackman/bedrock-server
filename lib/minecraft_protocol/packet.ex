defmodule BedrockProtocol.Packet do

  alias BedrockProtocol.Message

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """
  use Bitwise

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

  def encode_uint24(value),
    do: <<value::big-size(24)>>

  def encode_uint16(value),
    do: <<value::big-size(16)>>

  def encode_uint8(value),
    do: <<value::big-size(8)>>

  @doc """
  Encodes an ip address.
  """
  def encode_ip(4, address, port) do
    {a1, a2, a3, a4} = address

    encode_uint8(4)     <>
    <<255-a1::size(8)>> <>
    <<255-a2::size(8)>> <>
    <<255-a3::size(8)>> <>
    <<255-a4::size(8)>> <>
    encode_uint16(port)
  end

  @doc """
  Encodes a string.
  """
  def encode_string(string) do
    #strlen = encode_varint(byte_size(string))
    #<<strlen::binary, string::binary>>
    <<string::binary>>
  end

  @doc """
  Encodes a sequence number. These are three bytes in size.
  """
  def encode_seq_number(num) do
    encode_uint24(num)
  end

  @doc """
  Encodes a message id.
  """
  def encode_msg(id) do
    <<Message.binary(id)>>
  end

  @doc """
  Encodes a packet flag.
  """
  def encode_flag(flag) when flag <= 255 do
    encode_uint8(flag)
  end

end