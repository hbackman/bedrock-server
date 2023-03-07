# Aetheria

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bedrock_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bedrock_server, "~> 0.1.0"}
  ]
end
```

---


https://github.com/CloudburstMC/Server

Server boots in CloudServer::boot() [334]

Server ticks in CloudServer::tickProcessor() [741]


### Usage

Start an iex session with:

```console
iex -S mix
```

Now, send messages to the UDP server from another terminal:

```console
echo "hello world" | nc -u -w0 0.0.0.0 19132
```

Now, try to send a quit message:

```console
echo "quit" | nc -u -w0 0.0.0.0 19132
```

Windows:
```console
ncat.exe -u 172.19.221.219 19132
```