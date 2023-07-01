defmodule RakNet.Server do
  use GenServer

  require Logger

  alias RakNet.Packet
  alias RakNet.Message
  alias RakNet.Connection
  alias RakNet.Advertisement

  def start_link(opts) do
    Logger.info("Server starting on #{opts.port}")

    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    %{
      port: port,
      host: host,
      guid: _guid,
    } = opts

    # Start the connection registry. We use this to look up the current clients
    # to match with the incoming packet.
    {:ok, _} = Registry.start_link(keys: :unique, name: RakNet.Connection)

    # Use erlang's `:gen_udp` module to open a socket.
    # With options:
    #   - binary: request that data be returned as `String`/
    #   - active: gen_udp will handle data reception and send us a message `{:udp,
    #     socket, address, port, data}` when new data arrives.
    #   - ip: this binds the server to the given ip.
    #
    {:ok, socket} = :gen_udp.open(port, [
      :binary,
      {:ip, host}
    ])

    {:ok, opts |> Map.merge(%{
      socket: socket,
    })}
  end

  @doc "Retrieve the current server config."
  def config(pid) do
    GenServer.call(pid, :config)
  end

  @doc "The current unix timestamp, in milliseconds."
  def timestamp(offset \\ 0), do: :os.system_time(:millisecond) - offset

  @doc "Convert ip address to a string."
  def ip_to_string({ip0, ip1, ip2, ip3}) do
    "#{ip0}.#{ip1}.#{ip2}.#{ip3}"
  end

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
  @impl GenServer
  def handle_info({:udp, socket, host, port, data}, config) do
    case decode(socket, config, {host, port}, data) do
      {:connected,   {client, type, data}} -> handle_packet(socket, config, client, type, data)
      {:unconnected, {client, type, data}} -> handle_packet(socket, config, client, type, data)
    end
    {:noreply, config}
  end

  # Decode the packet. If the packet is a connected packet, then attempt to look it
  # up, and if not found, create a new connection.
  defp decode(socket, config, {host, port}, data) do
    case decode_packet(data) do
      {:error, _msg} = err ->
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

  # Look up a connection in the registry.
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

  # Create a new connection client.
  defp client(socket, config, {host, port}) do
    {:ok, client} =
      Connection.start_link(%Connection.State{
        host: host,
        port: port,
        send: gen_responder(socket, {host, port}),
        server_identifier: config.guid,
        client_module: config.client_module,
        client_data: config.client_data,
        base_time: timestamp(),
      })

    # Prevent the server from crashing if the connection fails. If this happens, we
    # can just reconnect.
    Process.unlink(client)

    Registry.register(Connection, {host, port}, client)

    Logger.debug("Created session for #{ip_to_string(host)}:#{port}")

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
      <> Packet.encode_int64(config.guid)
      <> Packet.offline()

    message_body = %{
      serverId: config.guid,
      ipv4Port: config.port,
      ipv6Port: config.portv6,
    } |> Advertisement.new()
      |> Advertisement.to_buffer()

    respond(socket, client, message_head <> message_body)

    {:ok}
  end

  @doc """
  Return the server config.
  """
  @impl GenServer
  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end
end
