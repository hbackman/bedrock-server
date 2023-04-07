defmodule ConnectionTest do
  use ExUnit.Case

  alias BedrockProtocol.Connection
  alias BedrockProtocol.Packet

  import Packet

  doctest BedrockProtocol.Connection

  defp new_connection() do
    %Connection.State{
      host: {127, 0, 0, 1},
      port: 12345,
      send: fn data ->
        send(self(), {:sent, data})
      end,
      server_identifier: <<0x8d, 0xe7, 0xee, 0x79, 0x41, 0xe6, 0xf2, 0xce>>,
    }
  end

  test ":client_connect" do
    # Attempt to send a client connect message to the connection.
    # Format:
    #   - client_id::size(64)
    #   - time_sent::size(64)
    #   - use_security::size(8)
    msg = <<>>
      <> <<0xbf, 0xfd, 0x76, 0xdc, 0x34, 0x56, 0x4e, 0x7a>>
      <> encode_timestamp(BedrockServer.timestamp())
      <> encode_bool(false)

    Connection.handle_cast({:client_connect, msg}, new_connection())

    # The response is formatted:
    # - message id
    # - client address
    # - _not_sure
    # - _not_sure_but_its_10_ips
    # - time sent
    # - time pong

    assert_receive {:sent, <<
      # Encapsulation prefix.
      _::binary-size(14),

      _::id,
      _::ip(4),
      _::uint8,

      # Unsure why we need to send 10 empty ips, but we do.
      _::ip(4), _::ip(4), _::ip(4),
      _::ip(4), _::ip(4), _::ip(4),
      _::ip(4), _::ip(4), _::ip(4),
      _::ip(4),

      # Timestamps.
      _::timestamp,
      _::timestamp,
    >>}
  end

  test ":client_handshake" do
    # Attempt to send a client handshake message to the connection.
    # Format:
    #   - server_ip
    #   - client_ip
    #   - _some_timestamp
    #   - _some_timestamp
    msg = <<>>
      <> encode_ip(4, {127, 0, 0, 1}, 19132)
      <> encode_ip(4, {127, 0, 0, 1}, 19132)
      <> <<BedrockServer.timestamp()::timestamp>>
      <> <<BedrockServer.timestamp()::timestamp>>

    Connection.handle_cast({:client_handshake, msg}, new_connection())

    receive do
      {:sent} -> assert false
    after
      500 -> assert true
    end
  end

end
