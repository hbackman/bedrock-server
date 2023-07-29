defmodule RakNet.Packet do

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """

  require RakNet.Packet

  alias RakNet.Reliability
  alias RakNet.Message

  import Bitwise

  # ------------------------------------------------------------
  # Macros
  # ------------------------------------------------------------

  @doc """
  Macro for smaller decoders.
  """
  defmacro decode_using(buffer, type) do
    quote do
      <<v::unquote(type), r::binary>> = unquote(buffer)
      {v, r}
    end
  end

  defmacro timestamp do
    quote do: size(64)
  end

  defmacro ip(version) do
    case version do
      4 -> quote do: size(56)
      6 -> quote do: nil # todo
    end
  end

  defmacro bool() do
    quote do: size(8)
  end

  defmacro id() do
    quote do: size(8)
  end

  defmacro uint24le do
    quote do: little-size(24)
  end

  defmacro magic do
    quote do: binary-size(16)
  end

  # "Magic" bytes used to distinguish offline messages from garbage
  def offline, do: <<0x00, 0xff, 0xff, 0x00, 0xfe, 0xfe, 0xfe, 0xfe, 0xfd, 0xfd, 0xfd, 0xfd, 0x12, 0x34, 0x56, 0x78>>

  # ------------------------------------------------------------
  # Decode
  # ------------------------------------------------------------

  @doc """
  Decode a buffer containing packets.
  """
  def decode_packets(data, packets \\ [])
  def decode_packets("", packets) do
    Enum.reverse(packets)
  end

  def decode_packets(data, packets) do
    {packet, rest} = RakNet.Reliability.Frame.decode(data)
    decode_packets(rest, [packet | packets])
  end

  @doc """
  Decodes a variable-size integer.
  """
  def decode_varint(data) when is_binary(data),
    do: decode_varint(data, 0, 0)

  defp decode_varint(<<1::1, byte::7, rest::binary>>, num_read, acc) when num_read < 5 do
    decode_varint(rest, num_read + 1, acc + (byte <<< (7 * num_read)))
  end

  defp decode_varint(<<0::1, byte::7, rest::binary>>, num_read, acc) do
    result = acc + (byte <<< (7 * num_read))
    {result, rest}
  end

  defp decode_varint(_, num_read, _) when num_read >= 5, do: {:error, :too_long}
  defp decode_varint("", _, _), do: {:error, :too_short}

  @doc """
  Decodes a string.
  """
  def decode_string(data) do
    {strlen, data} = decode_int16(data)
    <<string::binary-size(strlen), rest::binary>> = data
    {string, rest}
  end

  @doc """
  Decodes a boolean.
  """
  def decode_bool(data) when is_binary(data) do
    <<b::bool, rest::binary>> = data

    {decode_bool(b), rest}
  end

  def decode_bool(0), do: false
  def decode_bool(1), do: true

  def decode_int8(value),  do: decode_using(value,  8-integer)
  def decode_int16(value), do: decode_using(value, 16-integer)
  def decode_int24(value), do: decode_using(value, 24-integer)
  def decode_int64(value), do: decode_using(value, 64-integer)

  # ------------------------------------------------------------
  # Encode
  # ------------------------------------------------------------

  @doc """
  Encode a batch of frames.
  """
  def encode_packets(packets, seq) when is_list(packets) do
    :erlang.iolist_to_binary([
      encode_seq_number(seq),
      Enum.map(packets, fn packet ->
        RakNet.Reliability.Frame.encode(packet)
      end)
    ])
  end

  @doc """
  Encodes a string.
  """
  def encode_string(value) when is_binary(value) do
    strlen = encode_int16(byte_size(value))
    <<strlen::binary, value::binary>>
  end

  @doc """
  Encodes a boolean.
  """
  def encode_bool(false), do: <<0>>
  def encode_bool(true),  do: <<1>>

  def encode_int8(value),  do: <<value:: 8-integer>>
  def encode_int16(value), do: <<value::16-integer>>
  def encode_int24(value), do: <<value::24-integer>>
  def encode_int64(value), do: <<value::64-integer>>

  @doc """
  Encodes an ip address.
  """
  def encode_ip(4, address, port) do
    {a1, a2, a3, a4} = address

    encode_int8(4) <>
    <<255-a1::8>> <>
    <<255-a2::8>> <>
    <<255-a3::8>> <>
    <<255-a4::8>> <>
    encode_int16(port)
  end

  @doc """
  Encodes a sequence number. These are three bytes in size.
  """
  def encode_seq_number(num) do
    <<num::24-little>>
  end

  @doc """
  Encodes a timestamp.
  """
  def encode_timestamp(time) do
    <<time::timestamp>>
  end

  @doc """
  Encodes a reliability flag.
  """
  def encode_reliability(num) do
    <<Reliability.binary(num)::3-unsigned>>
  end

  @doc """
  Encodes a message id.
  """
  def encode_msg(id) do
    <<Message.binary(id)>>
  end
end
