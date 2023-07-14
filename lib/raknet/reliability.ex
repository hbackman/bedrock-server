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
end
