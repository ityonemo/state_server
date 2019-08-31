defmodule StateServerTest.Callbacks.DelayedUpdateTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer

    @state_graph [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call(:go, _from, _state, fun) when is_function(fun, 0), do: fun.()

    @impl true
    def handle_internal({:wait, test_pid}, _state, _data) do
      send(test_pid, :waiting)
      receive do :release -> :ok end
      :noreply
    end
  end

  test "delayed update functions are respected" do

    test_pid = self()

    # in this test we provide a transition action, but it's not at the head
    # of the function.

    {:ok, srv} = Instrumented.start_link(fn ->
      {:reply, "foo", internal: {:wait, test_pid}, update: "foo"}
    end)

    assert {:start, f} = Instrumented.state(srv)
    assert "foo" = StateServer.call(srv, :go)

    receive do :waiting -> send(srv, :release) end

    assert {:start, "foo"} = Instrumented.state(srv)
  end

end
