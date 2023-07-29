#defmodule RakNetTest do
#
#  use ExUnit.Case
#
#  alias RakNet.Connection
#  alias RakNet.Packet
#  alias RakNet.Server
#  alias RakNet.Message
#
#  import Packet
#
#  @server_host {127, 0, 0, 1}
#  @server_port 19132
#
#  @doc """
#  Macro for asserting that a packet sent by the server match the given pattern.
#  """
#  defmacro assert_packet(spec) do
#    quote do
#      assert_receive {
#        :udp,
#        _port,
#        _server_host,
#        _server_port,
#        unquote(spec)
#      }
#    end
#  end
#
#  @doc """
#  Bitstring data type for buffers.
#  """
#  defmacro buffer(string) do
#    quote do: binary-size(byte_size(unquote(string)))
#  end
#
#  #defp new_connection() do
#  #  here = self()
#  #  %Connection.State{
#  #    host: {127, 0, 0, 1},
#  #    port: 12345,
#  #    send: fn data ->
#  #      send(here, {:sent, data})
#  #    end,
#  #    server_identifier: 13547959620129336354,
#  #  }
#  #end
#
#  defp make_server() do
#    Server.start_link(%{
#      port: @server_port,
#      host: @server_host,
#      guid: 13547959620129336354,
#      client_module: BedrockServer.Client.State,
#      client_data: %{},
#    })
#  end
#
#  defp make_server!() do
#    {:ok, server} = make_server()
#    server
#  end
#
#  # Build sender function.
#  defp make_sender(server_pid, client_port) do
#    config = Server.config(server_pid)
#
#    {:ok, socket} = :gen_udp.open(client_port, [:binary])
#    {:ok, fn buffer ->
#      :gen_udp.send(
#        socket,
#        config.host,
#        config.port,
#        buffer
#      )
#    end}
#  end
#
#  defp make_sender!(server_pid, client_port \\ 49_100) do
#    {:ok, sender} = make_sender(server_pid, client_port)
#    sender
#  end
#
#  # Attempt to send the server an unconnected ping.
#  #
#  test :unconnected_ping do
#    msg = <<>>
#      <> Message.binary(:unconnected_ping, true)
#      <> encode_timestamp(RakNet.Server.timestamp())
#      <> Packet.offline()
#
#    server = make_server!()
#    sender = make_sender!(server)
#
#    sender.(msg)
#
#    config = Server.config(server)
#
#    advertisement = %{
#      serverId: config.guid,
#      ipv4Port: config.port,
#      ipv6Port: config.port,
#    } |> RakNet.Advertisement.new()
#      |> RakNet.Advertisement.to_buffer()
#
#    assert_packet <<
#      0x1c::id,
#      _::64-integer,
#      _::64-integer,
#      _::magic,
#      ^advertisement::buffer(advertisement),
#    >>
#  end
#
#  # Attempt to send the server an unconnected ping. The server should only
#  # reply to this if the server has active connections.
#  #
#  test :unconnected_ping_2 do
#    # todo
#  end
#
#  defp send_connection_request_1({server, sender}) do
#    msg = <<>>
#      <> Message.binary(:open_connection_request_1, true)
#      <> Packet.offline()
#      <> Packet.encode_int8(11)
#      <> <<0x00, 0x00>>
#
#    sender.(msg)
#
#    {server, sender}
#  end
#
#  # Attempt to send the server an open connection request 1. This test will
#  # not cover MTU detection and will assume an MTU of 1400.
#  #
#  test :open_connection_request_1 do
#    server = make_server!()
#    sender = make_sender!(server)
#
#    send_connection_request_1({server, sender})
#
#    sec = Packet.encode_bool(false)
#    mtu = Packet.encode_int16(1400)
#
#    assert_packet <<
#     0x06::id,
#     _::magic,
#     _::64-integer,
#     ^sec::buffer(sec),
#     ^mtu::buffer(mtu),
#   >>
#  end
#
#  defp send_connection_request_2({server, sender}) do
#    cnf = Server.config(server)
#    msg = <<>>
#      <> Message.binary(:open_connection_request_2, true)
#      <> Packet.offline()
#      <> Packet.encode_ip(4, cnf.host, cnf.port)
#      <> Packet.encode_int8(1400)
#
#    sender.(msg)
#
#    {server, sender}
#  end
#
#  # Attempt to send the server an open connection request 2. This test will
#  # not cover MTU detection and will assume an MTU of 1400.
#  #
#  test :open_connection_request_2 do
#    server = make_server!()
#    sender = make_sender!(server)
#
#    {server, sender}
#      |> send_connection_request_1()
#      |> send_connection_request_2()
#
#    mtu = Packet.encode_int16(1400)
#    enc = Packet.encode_bool(false)
#
#    assert_packet <<
#      0x08::id,
#      _::magic,
#      _::64-integer,
#      _::ip(4),
#      ^mtu::buffer(mtu),
#      ^enc::buffer(enc),
#    >>
#  end
#
#  defp send_client_connect({server, sender}) do
#    msg = <<>>
#      <> Message.binary(:client_connect, true)
#      <> Packet.encode_int64(123)
#      <> Packet.encode_timestamp(Server.timestamp())
#      <> Packet.encode_int8(0)
#
#    sender.(msg)
#
#    {server, sender}
#  end
#
#  test :connection_request do
#    server = make_server!()
#    sender = make_sender!(server)
#
#    {server, sender}
#      |> send_connection_request_1()
#      |> send_connection_request_2()
#      |> send_client_connect()
#
#    ips = Packet.encode_ip(4, {255, 255, 255, 255}, 0)
#      |> List.duplicate(10)
#      |> :erlang.list_to_binary
#
#    assert_packet <<
#      0x10::id,
#      _::ip(4),
#      _::int16,
#      ^ips::buffer(ips),
#      _::64-integer,
#      _::64-integer,
#    >>
#  end
#
##  test ":client_connect" do
##    # Attempt to send a client connect message to the connection.
##    # Format:
##    #   - client_id::size(64)
##    #   - time_sent::size(64)
##    #   - use_security::size(8)
##    msg = <<>>
##      <> <<0xbf, 0xfd, 0x76, 0xdc, 0x34, 0x56, 0x4e, 0x7a>>
##      <> encode_timestamp(RakNet.Server.timestamp())
##      <> encode_bool(false)
##
##    {:ok, pid} = Connection.start(new_connection())
##
##    Connection.handle_message(pid, :client_connect, msg)
##
##    # The response is formatted:
##    # - message id
##    # - client address
##    # - _not_sure
##    # - _not_sure_but_its_10_ips
##    # - time sent
##    # - time pong
##
##    assert_receive {:sent, <<
##      # Encapsulation prefix.
##      _::binary-size(14),
##
##      _::id,
##      _::ip(4),
##      _::int8,
##
##      # Unsure why we need to send 10 empty ips, but we do.
##      _::ip(4), _::ip(4), _::ip(4),
##      _::ip(4), _::ip(4), _::ip(4),
##      _::ip(4), _::ip(4), _::ip(4),
##      _::ip(4),
##
##      # Timestamps.
##      _::timestamp,
##      _::timestamp,
##    >>}, 500
##  end
#
##  test ":new_incoming_connection" do
##    # Attempt to send a client handshake message to the connection.
##    # Format:
##    #   - server_ip
##    #   - client_ip
##    #   - _some_timestamp
##    #   - _some_timestamp
##    msg = <<>>
##      <> encode_ip(4, {127, 0, 0, 1}, 19132)
##      <> encode_ip(4, {127, 0, 0, 1}, 19132)
##      <> <<RakNet.Server.timestamp()::timestamp>>
##      <> <<RakNet.Server.timestamp()::timestamp>>
##
##    {:ok, pid} = Connection.start(new_connection())
##
##    Connection.handle_message(pid, :new_incoming_connection, msg)
##
##    receive do
##      {:sent} -> assert false
##    after
##      500 -> assert true
##    end
##  end
#
#end
#
