defmodule StateServerTest.Callbacks.TerminateTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(resp_pid), do: StateServer.start_link(__MODULE__, resp_pid)

    @impl true
    def init(resp_pid), do: {:ok, resp_pid}

    @impl true
    def handle_call(:tr, _reply, _state, _data) do
      {:reply, nil, transition: :tr}
    end

    @impl true
    def terminate(_reason, state, resp_pid) do
      send(resp_pid, {:terminating_from, state})
      :this_is_ignored
    end
  end

  describe "instrumenting terminate" do
    test "works from the initial state" do
      {:ok, srv} = Instrumented.start_link(self())
      Process.exit(srv, :normal)
      assert_receive {:terminating_from, :start}
    end

    test "works from another state state" do
      {:ok, srv} = Instrumented.start_link(self())
      GenServer.call(srv, :tr)
      Process.exit(srv, :normal)
      assert_receive {:terminating_from, :start}
    end
  end
end
