# Aetheria

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `aetheria` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aetheria, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/aetheria>.

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
echo "hello world" | nc -u -w0 0.0.0.0 2052
```

Now, try to send a quit message:

```console
echo "quit" | nc -u -w0 0.0.0.0 2052
```