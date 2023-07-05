defmodule BedrockServer.Zlib do
  @moduledoc """
  This module provides function to compress and decompress data using :zlib.
  """

  @doc """
  Compresses a buffer using zlib without zlib headers and checksum.

  iex> BedrockServer.Zlib.inflate(<<203, 72, 205, 201, 201, 7, 0>>)
  "hello"
  """
  def inflate(buffer) when is_binary(buffer) do
    z = :zlib.open()

    :zlib.inflateInit(z, -15)

    uncompressed = :zlib.inflate(z, buffer)

    :zlib.inflateEnd(z)

    uncompressed
      |> List.flatten()
      |> Enum.into(<<>>)
  end

  @doc """
  Decompresses a buffer using zlib without zlib headers and checksum.

  iex> BedrockServer.Zlib.deflate("hello")
  <<203, 72, 205, 201, 201, 7, 0>>
  """
  def deflate(buffer) when is_binary(buffer) do
    z = :zlib.open()

    :zlib.deflateInit(z, :default, :deflated, -15, 8, :default)

    [data] = :zlib.deflate(z, buffer, :finish)

    :zlib.deflateEnd(z)

    data
  end
end
