defmodule StateServerTest.StateModule.TerminateTest do

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
    def terminate(_reason, _state, resp_pid) do
      send(resp_pid, :terminating_start)
      :this_is_ignored
    end

    defstate End, for: :end do
      @impl true
      def terminate(_reason, resp_pid) do
        send(resp_pid, :terminating_end)
        :this_is_ignored
      end
    end
  end

  describe "instrumenting terminate" do
    @describetag :one
    test "works outside a state module" do
      {:ok, srv} = Instrumented.start(self())
      StateServer.call(srv, :stop)
      assert_receive :terminating_start
      refute Process.alive?(srv)
    end

    test "works inside a state module" do
      {:ok, srv} = Instrumented.start(self())
      StateServer.call(srv, :tr)
      StateServer.call(srv, :stop)
      assert_receive :terminating_end
    end
  end
end
