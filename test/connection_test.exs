defmodule ConnectionTest do
  use ExUnit.Case

  alias BedrockProtocol.Connection
  alias BedrockProtocol.Packet

  doctest BedrockProtocol.Connection

  test ":client_connect" do
    con = %Connection.State{
      host: {127, 0, 0, 1},
      port: 12345,
      send: fn _ ->
        send self, {:sent}
      end,
      server_identifier: <<0x8d, 0xe7, 0xee, 0x79, 0x41, 0xe6, 0xf2, 0xce>>,
    }

    msg = <<>>
      <> <<0xbf, 0xfd, 0x76, 0xdc, 0x34, 0x56, 0x4e, 0x7a>>
      <> <<BedrockServer.timestamp()::size(64)>>
      <> Packet.encode_bool(false)

    Connection.handle_cast({:client_connect, msg}, con)

    assert_received {:sent}
  end

end