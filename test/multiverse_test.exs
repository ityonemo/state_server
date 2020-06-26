defmodule StateServerTest.MultiverseTest do

  # tests to make sure we can imbue StateServer with
  # the ability to forward its caller.

  defmodule TestServer do
    use StateServer, on: []

    def start_link(opts) do
      StateServer.start_link(__MODULE__, nil, opts)
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call(:caller, _, _state, _data) do
      {:reply, Process.get(:"$callers")}
    end
  end

  use ExUnit.Case, async: true

  @tag :one
  test "basic state_server caller functionality" do
    {:ok, srv} = TestServer.start_link(forward_callers: true)
    assert [self()] == GenServer.call(srv, :caller)
  end

end
