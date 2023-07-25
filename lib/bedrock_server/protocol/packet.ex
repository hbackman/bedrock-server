defmodule BedrockServer.Protocol.Packet do
  @doc """
  Decode the packet.
  """
  @callback decode(bitstring()) :: {:ok, struct()} | {:error, any()}

  @doc """
  Encode the packet.
  """
  @callback encode(map()) :: {:ok, bitstring()} | {:error, any()}
end
