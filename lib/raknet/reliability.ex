defmodule RakNet.Reliability do

  @reliability_lookup %{
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

  def binary(value) when is_atom(value) do
    Map.fetch!(@reliability_lookup, value)
  end

  def is_reliable?(value) when is_integer(value), do: value in [2, 3, 4, 6, 7]
  def is_reliable?(value) when is_atom(value), do: is_reliable?(binary(value))

  def is_ordered?(value) when is_integer(value), do: value == 3
  def is_ordered?(value) when is_atom(value), do: is_ordered?(binary(value))

  def is_sequenced?(value) when is_integer(value), do: value in [1, 3, 4, 7]
  def is_sequenced?(value) when is_atom(value), do: is_sequenced?(binary(value))

end

defmodule RakNet.Reliability.Packet do
  defstruct [
    :reliability,

    :has_split,

    :order_index,
    :order_channel,

    :split_count,
    :split_id,
    :split_index,

    :sequencing_index,

    :message_index,
    :message_length,
    :message_id,
    :message_buffer
  ]
end