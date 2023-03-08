defmodule BedrockServer do
  use GenServer

  alias BedrockProtocol.Message
  alias BedrockProtocol.Packet
  alias BedrockProtocol.Advertisement

  # Use a factory to start up the server. This runs from the caller context.
  def start_link(port) do
    IO.puts("Server starting on #{port}")

    GenServer.start_link(__MODULE__, port)
  end

  # Initialize the server. This runs in the server context.
  def init(port) do
    options = [
      :binary,
    ]
    # Use erlang's `gen_udp` module to open a socket.
    # With options:
    #   - binary: request that data be returned as `String`.
    #   - active: gen_udp will handle data reception and send us a message `{:udp, socket, address, port ,data}` when new data arrives.
    {:ok, port} = :gen_udp.open(port, options)

    {:ok, %{
      port: port,
      guid: <<0x8d, 0xe7, 0xee, 0x79, 0x41, 0xe6, 0xf2, 0xce>>,
    }}
  end

  # Send a UDP packet.
  defp respond({socket, host, port}, data) do
    :gen_udp.send(socket, host, port, data)
  end

  # Handle incoming udp data.
  def handle_info({:udp, socket, host, port, data}, context) do
    {:ok, name, data} = decode_packet(data)

    {:ok} = handle_packet(context, {socket, host, port}, name, data)
    
    # GenServer will understand this as "stop the server".
    #{:stop, :normal, nil}

    {:noreply, context}
  end

  # Handle a :id_login event.
  defp handle_packet(ctx, client, :id_unconnected_ping, data) do
    <<ping_time::size(64), _::binary>> = data

    message_head = <<
      Message.binary(:id_unconnected_pong),
      ping_time::size(64),
      Message.unique_id()::binary,
      Message.offline()::binary,
    >>

    message_body = %{
      serverId: ctx.guid,
      ipv4Port: 19132,
      ipv6Port: 19132,
    } |> Advertisement.new()
      |> Advertisement.to_buffer()

    respond(client, message_head <> message_body)

    {:ok}
  end

  # Handle the open connection request.
  defp handle_packet(ctx, client, :id_open_connection_request_1, _) do

    # RakNet Offline Message ID: Open Connection Reply 1 (0x06)
    # RakNet Offline Message Data ID: 00ffff00fefefefefdfdfdfd12345678
    # RakNet Server GUID: 8de7ee7941e6f2ce
    # RakNet Use encryption: false
    # RakNet MTU size: 1400

    IO.puts ":open_connection_request_1"

    message = <<
      Message.binary(:id_open_connection_reply_1),
      Message.offline()::binary,
    >> <> ctx.guid
       <> Packet.encode_bool(false)
       <> Packet.encode_uint16(1400)
       |> Hexdump.inspect

    respond(client, message)

    {:ok}
  end

  # Handle the open connection request 2.
  defp handle_packet(ctx, client, :id_open_connection_request_2, _) do

    IO.puts ":open_connection_request_2"

    # RakNet Offline Message ID: Open Connection Reply 2 (0x08)
    # RakNet Offline Message Data ID
    # RakNet Server GUID
    # RakNet Client address:
    #   - IP Version: 4
    #   - Ipv4 Address: 127.0.0.1
    #   - Port: 56685
    # RakNet MTU size: 1400

    {_, host, port} = client

    message = <<
      Message.binary(:id_open_connection_reply_2),
      Message.offline()::binary,
    >> <> ctx.guid
       <> Packet.encode_ip(4, host, port)
       <> Packet.encode_uint16(1400)
       <> Packet.encode_bool(false)
       |> Hexdump.inspect

    respond(client, message)

    {:ok}
  end

  defp decode_packet(<<identifier::unsigned-size(8), data::binary>>) do
    case Message.name(identifier) do
      name -> {:ok, name, data}
    end
  end
end