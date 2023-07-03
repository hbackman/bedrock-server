defmodule RakNet.Packet do

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """

  alias RakNet.Reliability
  alias RakNet.Message

  import Bitwise

  # ------------------------------------------------------------
  # Macros
  # ------------------------------------------------------------

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

  defmacro int8 do
    quote do: big-size(8)
  end

  defmacro int16 do
    quote do: big-size(16)
  end

  defmacro int24 do
    quote do: big-size(24)
  end

  defmacro int64 do
    quote do: big-size(64)
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

  def decode_packets(data, packets \\ [])
  def decode_packets("", packets) do
    Enum.reverse(packets)
  end

  def decode_packets(data, packets) do
    {packet, rest} = decode_encapsulated(data)
    decode_packets(rest, [packet | packets])
  end

  @doc """
  Decode encapsulated messages.
  """
  def decode_encapsulated(data) do
    # Decode reliability.
    <<reliability::unsigned-size(3), has_split::unsigned-size(5), data::binary>> = data

    is_reliable = Reliability.is_reliable?(reliability)
    is_sequenced = Reliability.is_sequenced?(reliability)

    # Decode the length.
    <<length::size(16), data::binary>> = data
    length = trunc(Float.ceil(length / 8))

    # Decode sequence.
    {message_index, data} =
      if is_sequenced or is_reliable do
        <<message_index::little-size(24), rest::binary>> = data
        {message_index, rest}
      else
        {nil, data}
      end

    # Decode order.
    {order_index, order_channel, data} =
      if is_sequenced do
        <<order_index::little-size(24), order_channel::size(8), rest::binary>> = data
        {order_index, order_channel, rest}
      else
        {nil, nil, data}
      end

    # Decode split.
    {split_count, split_id, split_index, data} =
      if has_split > 0 do
        <<
          split_count::size(32),
          split_id   ::size(16),
          split_index::size(32),
          rest::binary
        >> = data
        {split_count, split_id, split_index, rest}
      else
        {nil, nil, nil, data}
      end

    <<buffer::binary-size(length), rest::binary>> = data

    # The message is sometimes a minecraft specific message. This doesnt match anything
    # in the message module. I will probably have to wait unwrapping the message id so
    # that a custom packet can implement the lookup.

    {%Reliability.Frame{
      reliability: Reliability.name(reliability),

      has_split: has_split > 0,

      order_index: order_index,
      order_channel: order_channel,

      split_id: split_id,
      split_count: split_count,
      split_index: split_index,

      sequencing_index: if(is_reliable, do: nil, else: message_index),
      message_index: if(is_reliable, do: message_index, else: nil),
      message_length: length,
      message_buffer: buffer,
    }, rest}
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
    {strlen, data} = decode_varint(data)
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

  # ------------------------------------------------------------
  # Encode
  # ------------------------------------------------------------

  def encode(packets, seq) when is_list(packets) do
    :erlang.iolist_to_binary([
      encode_seq_number(seq),
      Enum.map(packets, fn packet ->
        encode_encapsulated(packet)
      end)
    ])
  end

  @doc """
  Encode encapsulated messages.
  """
  def encode_encapsulated(frame = %Reliability.Frame{}) do
    is_reliable = Reliability.is_reliable?(frame.reliability)
    is_sequenced = Reliability.is_sequenced?(frame.reliability)

    index = if is_reliable,
      do: frame.message_index,
    else: frame.sequencing_index

    header = <<
      Reliability.binary(frame.reliability)::unsigned-size(3),
      frame.has_split::unsigned-size(5),
    >>

    message = <<
      trunc(byte_size(frame.message_buffer) * 8)::size(16)
    >><> if is_reliable or is_sequenced do
        <<index::little-size(24)>> <>
          if is_sequenced do
            <<
              frame.order_index::little-size(24),
              frame.order_channel::size(8)
            >>
          else
            <<>>
          end
      else
        <<>>
      end
      <> if frame.has_split > 0 do
        <<
          frame.split_count::size(32),
          frame.split_id::size(16),
          frame.split_index::size(32),
        >>
      else
        <<>>
      end

    header <> message <> frame.message_buffer
  end

  @doc """
  Encodes a string.
  """
  def encode_string(value) when is_bitstring(value) do
    strlen = encode_int16(byte_size(value))
    <<strlen::binary, value::binary>>
  end

  @doc """
  Encodes a boolean.
  """
  def encode_bool(false), do: <<0>>
  def encode_bool(true),  do: <<1>>

  def encode_byte(value),
    do: <<value::size(1)>>

  def encode_int8(value),  do: <<value::int8>>
  def encode_int16(value), do: <<value::int16>>
  def encode_int24(value), do: <<value::int24>>
  def encode_int64(value), do: <<value::int64>>

  @doc """
  Encodes an ip address.
  """
  def encode_ip(4, address, port) do
    {a1, a2, a3, a4} = address

    encode_int8(4)     <>
    <<255-a1::size(8)>> <>
    <<255-a2::size(8)>> <>
    <<255-a3::size(8)>> <>
    <<255-a4::size(8)>> <>
    encode_int16(port)
  end

  @doc """
  Encodes a sequence number. These are three bytes in size.
  """
  def encode_seq_number(num) do
    <<num::little-size(24)>>
  end

  @doc """
  Encodes a reliability flag.
  """
  def encode_reliability(num) do
    <<Reliability.binary(num)::unsigned-size(3)>>
  end

  @doc """
  Encodes a message id.
  """
  def encode_msg(id) do
    <<Message.binary(id)>>
  end

  @doc """
  Encodes a timestamp.
  """
  def encode_timestamp(time) do
    <<time::timestamp>>
  end

end
