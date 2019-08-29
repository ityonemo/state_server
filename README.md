# StateServer

**Opinionated :gen_statem shim for Elixir**

There are three major objectives:
  -  Fanout the callback handling
  -  Unify callback return type with that of `GenServer`, and sanitize
  -  Enforce the use of a programmer-defined state graph.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `state_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:state_server, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/state_server](https://hexdocs.pm/state_server).

