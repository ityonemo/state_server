defmodule StateServerTest.Callbacks.TransitionTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, state_graph: [start: [tr: :end], end: []]

    def start_link, do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(any), do: {:ok, any}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:transition, transition}, _from, _state, _data) do
      {:reply, "foo", [:noop, transition: transition]}
    end
  end

  test "transition can be used to change states" do
    {:ok, srv} = Instrumented.start_link()

    assert {:start, :ok} == Instrumented.state(srv)

    assert "foo" == StateServer.call(srv, {:transition, :tr})

    assert {:end, :ok} == Instrumented.state(srv)
  end

  test "going via a bad transition is not allowed" do
    test_pid = self()

    # spawn the state server to avoid linking on crash.
    spawn(fn ->
      {:ok, pid} = Instrumented.start_link()
      send(test_pid, pid)
    end)

    srv = receive do pid -> pid end

    assert {:start, :ok} == Instrumented.state(srv)

    # issue an invalid transition
    StateServer.call(srv, {:transition, :undefined})

    Process.sleep(100)

    refute Process.alive?(srv)
  end
end
