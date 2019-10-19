# StateServer

## Opinionated :gen_statem shim for Elixir

> A foolish consistency is the hobgoblin of little minds,
> adored by little statemen and philosophers and divines.
> With consistency a great soul has simply nothing to do.
>
> -- Ralph Waldo Emerson

The unusual callback pattern of `:gen_statem` exists to allow code
organization which we have better ways of achieving in Elixir (versus
erlang).  On the other hand we want to make sure users are using the
canonical `:gen_statem` to leverage and prove out its battle-testedness

This library makes `:gen_statem` more consistent with how Elixir
architects its `GenServer`s.

There are three major objectives:

- Fanout the callback handling
- Unify callback return type with that of `GenServer`, and sanitize
- Enforce the use of a programmer-defined state graph.

## Installation

The package can be installed by adding `state_server` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:state_server, "~> 0.3.1"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/state_server](https://hexdocs.pm/state_server).

## Example

```elixir
defmodule Demo do
  use StateServer, on: [flip: :off],
                   off: [flip: :on]

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
