defmodule StateServerTest.Callbacks.TerminateTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start(resp_pid), do: StateServer.start(__MODULE__, resp_pid)

    @impl true
    def init(resp_pid) do
      {:ok, resp_pid}
    end

    @impl true
    def handle_call(:tr, _from, _state, _data) do
      {:reply, nil, transition: :tr}
    end
    def handle_call(:stop, from, _state, resp_pid) do
      reply(from, nil)
      {:stop, :normal, resp_pid}
    end

    @impl true
    def terminate(_reason, state, resp_pid) do
      send(resp_pid, {:terminating_from, state})
      :this_is_ignored
    end
  end

  describe "instrumenting terminate" do
    test "works from the initial state" do
      {:ok, srv} = Instrumented.start(self())
      StateServer.call(srv, :stop)
      assert_receive {:terminating_from, :start}
      refute Process.alive?(srv)
    end

    test "works from another state state" do
      {:ok, srv} = Instrumented.start(self())
      StateServer.call(srv, :tr)
      StateServer.call(srv, :stop)
      assert_receive {:terminating_from, :end}
    end
  end
end
