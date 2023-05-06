defmodule BedrockServer do
  use GenServer

  require Logger

  alias RakNet.Message
  alias RakNet.Connection
  alias RakNet.Advertisement

  # Use a factory to start up the server. This runs from the caller context.
  def start_link(port) do
    Logger.debug("Server starting on #{port}")

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
    #   - active: gen_udp will handle data reception and send us a message `{:udp, socket, address, port, data}` when new data arrives.
    {:ok, port} = :gen_udp.open(port, options)

    {:ok, %{
      port: port,
      guid: <<0x8d, 0xe7, 0xee, 0x79, 0x41, 0xe6, 0xf2, 0xce>>,
    }}
  end

  @doc "The current unix timestamp, in milliseconds."
  def timestamp(offset \\ 0), do: :os.system_time(:millisecond) - offset

  # Send a UDP packet.
  defp respond(socket, {host, port}, data) do
    :gen_udp.send(socket, host, port, data)
  end

  # Generate a new responder that we can pass to the connection.
  defp gen_responder(socket, {host, port}) do
    fn data ->
      respond(socket, {host, port}, data)
    end
  end

  # Handle incoming udp data.
  def handle_info({:udp, socket, host, port, data}, config) do
    case decode(socket, config, {host, port}, data) do
      {:connected,   {client, type, data}} -> handle_packet(socket, config, client, type, data)
      {:unconnected, {client, type, data}} -> handle_packet(socket, config, client, type, data)
    end

    {:noreply, config}
  end

  # Decode the packet and return connection status.
  defp decode(socket, config, {host, port}, data) do
    case decode_packet(data) do
      {:error, msg} = err ->
        err

      {:ok, :open_connection_request_1, data} ->
        {:connected, {client(socket, config, {host, port}), :open_connection_request_1, data}}

      {:ok, :unconnected_ping, data} ->
        {:unconnected, {{host, port}, :unconnected_ping, data}}

      {:ok, packet_type, data} ->
        case lookup(host, port) do
          nil    -> {:unconnected, {{host, port}, packet_type, data}}
          client -> {:connected, {client, packet_type, data}}
        end
    end
  end

  # Decode a packet into the identifier and data.
  defp decode_packet(<<identifier::unsigned-size(8), data::binary>>) do
    case Message.name(identifier) do
      :error -> {:error, "Unknown packet identifier"}
      name   -> {:ok, name, data}
    end
  end

  defp lookup(host, port) do
    case Registry.lookup(Connection, {host, port}) do
      [{_, client}] ->
        if Process.alive?(client) do
          client
        else
          Registry.unregister(Connection, {host, port})
          nil
        end
      _ ->
        nil
    end
  end

  defp client(socket, config, {host, port}) do
    {:ok, client} =
      Connection.start_link(%Connection.State{
        host: host,
        port: port,
        send: gen_responder(socket, {host, port}),
        server_identifier: config.guid
      })

    # Prevent the server from crashing if the connection fails. If
    # this happens, we can just reconnect.
    Process.unlink(client)

    Registry.register(Connection, {host, port}, client)

    client
  end

  # Handle a connected packet.
  defp handle_packet(_socket, _config, client, type, data) when is_pid(client) do
    Connection.handle_message(client, type, data)
  end

  # Handle a unconnected packet.
  defp handle_packet(socket, config, client, type, data) do
    handle_message(socket, config, client, type, data)
  end

  defp handle_message(socket, config, client, :unconnected_ping, data) do
    <<ping_time::size(64), _::binary>> = data

    message_head = <<>>
      <> Message.binary(:unconnected_pong, true)
      <> <<ping_time::size(64)>>
      <> Message.unique_id()
      <> Message.offline()

    message_body = %{
      serverId: config.guid,
      ipv4Port: 19132,
      ipv6Port: 19132,
    } |> Advertisement.new()
      |> Advertisement.to_buffer()

    respond(socket, client, message_head <> message_body)

    {:ok}
  end
end
