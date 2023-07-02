defmodule RakNet.Protocol.Packet do

  @doc """
  The packet identifier.
  """
  @callback packet_id() :: atom()

  @doc """
  Decode a packet.
  """
  @callback decode(bitstring()) :: {:ok, struct()} | {:error, any()}

  @doc """
  Encode a packet.
  """
  @callback encode(map()) :: {:ok, bitstring()} | {:error, any()}

end
