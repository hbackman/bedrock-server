defmodule RakNet.Protocol.OpenConnectionReply2Test do
  use ExUnit.Case

  alias RakNet.Protocol.OpenConnectionReply2
  import RakNet.Packet

  defp make_buffer(with_msg \\ true) do
    buffer = if with_msg,
      do: <<>> <> encode_msg(:open_connection_reply_2),
    else: <<>>
    buffer
      <> offline()
      <> encode_int64(123456789)
      <> encode_ip(4, {255, 255, 255, 255}, 19132)
      <> encode_int16(150)
      <> encode_bool(false)
  end

  test "encode" do
    {:ok, packet} = %OpenConnectionReply2{
      server_id: 123456789,
      client_host: {255, 255, 255, 255},
      client_port: 19132,
      mtu: 150,
      use_encryption: false,
    } |> OpenConnectionReply2.encode()

    assert packet == make_buffer()
  end

  test "decode" do
    {status, message} = make_buffer(false)
      |> OpenConnectionReply2.decode()

    assert status == :error
    assert message == :not_implemented
  end
end
