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

### Example

```elixir
defmodule Demo do
  use StateServer, [on: [flip: :off], 
                                 off: [flip: :on]]

  def start_link(_), do: StateServer.start_link(__MODULE__, [], name: Demo)

  def init(state), do: {:ok, []}

  def handle_call(:flip, _from, state, data) do
    {:reply, data, transition: :flip, update: [state | data], timeout: {:foo, 100}}
  end

  def handle_transition(start, tr, data) do
    IO.puts("transitioned from #{start} through #{tr}")
    :noreply
  end

  def handle_timeout(_, _, _) do
    IO.puts("timed out!")
    :noreply
  end
end


iex(2)> Demo.start_link(:ok)
{:ok, #PID<0.230.0>}
iex(3)> GenServer.call(Demo, :flip)
transitioned from on through flip
[]
timed out!
iex(4)> GenServer.call(Demo, :flip)
transitioned from off through flip
[:on]
timed out!
iex(5)> GenServer.call(Demo, :flip)
transitioned from on through flip
[:off, :on]
timed out!
```