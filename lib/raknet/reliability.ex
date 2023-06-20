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

    has_split: 0,

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
end
