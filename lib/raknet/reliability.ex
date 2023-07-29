defmodule RakNet.Reliability do

  @reliability_map %{
    :unreliable => 0,
    :unreliable_sequenced => 1,
    :reliable => 2,
    :reliable_ordered => 3,
    :reliable_sequenced => 4,

    # These are the same as unreliable/reliable/reliable ordered, except that the business logic provider
    # will get an :ack message when the client acknowledges receipt
    :unreliable_ack_receipt => 5,
    :reliable_ack_receipt => 6,
    :reliable_ordered_ack_receipt => 7
  }

  @reliability_map_reverse Map.new(@reliability_map, fn {name, val} -> {val, name} end)

  def name(value) when is_integer(value) do
    Map.get(@reliability_map_reverse, value, :error)
  end

  def binary(value) when is_atom(value) do
    Map.fetch!(@reliability_map, value)
  end

  @doc """
  Checks if the value indicates a reliable packet.
  """
  def reliable?(value) when is_integer(value),
    do: reliable?(name(value))

  def reliable?(value) when is_atom(value) do
    Enum.member?([
      :reliable,
      :reliable_ordered,
      :reliable_sequenced,
      :reliable_ack_receipt,
      :reliable_ordered_ack_receipt,
    ], value)
  end

  @doc """
  Checks if the value indicates an ordered packet.
  """
  def ordered?(value) when is_integer(value),
    do: ordered?(name(value))

  def ordered?(value) when is_atom(value) do
    Enum.member?([
      :reliable_ordered,
      :reliable_ordered_ack_receipt,
    ], value)
  end

  @doc """
  Checks if the value indicates a sequenced packet.
  """
  def sequenced?(value) when is_integer(value),
    do: sequenced?(name(value))

  def sequenced?(value) when is_atom(value) do
    Enum.member?([
      :reliable_sequenced,
      :unreliable_sequenced,
    ], value)
  end

  def sequenced_or_ordered?(value) when is_integer(value),
    do: sequenced_or_ordered?(name(value))

  def sequenced_or_ordered?(value) when is_atom(value) do
    Enum.member?([
      :unreliable_sequenced,
      :reliable_sequenced,
      :reliable_ordered,
      :reliable_ordered_ack_receipt,
    ], value)
  end

end

defmodule RakNet.Reliability.Frame do
  defstruct [
    :reliability,

    has_split: false,

    order_index: nil,
    order_channel: 0,

    split_count: nil,
    split_id: nil,
    split_index: nil,

    sequencing_index: nil,

    message_index: nil,
    message_length: -1,
    message_id: nil,
    message_buffer: nil,
  ]

  alias RakNet.Reliability

  def encode(frame) do
    has_split = if frame.has_split,
      do: 1, else: 0

    header = <<
      Reliability.binary(frame.reliability)::3-unsigned,
      has_split::5-unsigned,
    >>

    message = <<>>
      <> <<trunc(byte_size(frame.message_buffer) * 8)::size(16)>>
      # Encode message index.
      <> if Reliability.reliable?(frame.reliability) do
        <<frame.message_index::24-little>>
          else
            <<>>
          end
      # Encode sequence index.
      <> if Reliability.sequenced?(frame.reliability) do
        <<frame.sequencing_index::24-little>>
      else
        <<>>
      end
      # Encode order.
      <> if Reliability.ordered?(frame.reliability) do
        <<
          frame.order_index::24-little,
          frame.order_channel::8,
        >>
      else
        <<>>
      end
      # Encode split.
      <> if frame.has_split do
        <<
          frame.split_count::32,
          frame.split_id::16,
          frame.split_index::32,
        >>
      else
        <<>>
      end

    header <> message <> frame.message_buffer
  end

  def decode(buffer) do
    # Decode reliability.
    <<reliability::3-unsigned, has_split::5-unsigned, data::binary>> = buffer

    # Decode the length.
    <<length::size(16), data::binary>> = data
    length = trunc(Float.ceil(length / 8))

    # Decode message index.
    {message_index, data} =
      if Reliability.reliable?(reliability) do
        <<message_index::24-little, rest::binary>> = data
        {message_index, rest}
      else
        {nil, data}
      end

    # Decode sequence.
    {sequencing_index, data} =
      if Reliability.sequenced?(reliability) do
        <<sequencing_index::24-little, rest::binary>> = data
        {sequencing_index, rest}
      else
        {nil, data}
      end

    # Decode order.
    {order_index, order_channel, data} =
      if Reliability.ordered?(reliability) do
        <<order_index::24-little, order_channel::8, rest::binary>> = data
        {order_index, order_channel, rest}
      else
        {nil, nil, data}
      end

    # Decode split.
    {split_count, split_id, split_index, data} =
      if has_split > 0 do
        <<
          split_count::32,
          split_id   ::16,
          split_index::32,
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

    {%__MODULE__{
      reliability: Reliability.name(reliability),

      has_split: has_split > 0,

      order_index: order_index,
      order_channel: order_channel,

      split_id: split_id,
      split_count: split_count,
      split_index: split_index,

      sequencing_index: sequencing_index,
      message_index: message_index,
      message_length: length,
      message_buffer: buffer,
    }, rest}
  end
end
