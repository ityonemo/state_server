defmodule StateServerTest.StateModule.HandleTransitionTest do

  use ExUnit.Case, async: true

  defmodule Undeferred do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data, timeout: {:internal_timeout, 200}}

    defstate Start, for: :start do
      @impl true
      def handle_timeout(:internal_timeout, _) do
        {:noreply, transition: :tr}
      end

      @impl true
      def handle_transition(:tr, resp_pid) do
        send(resp_pid, {:response, "foo"})
        :noreply
      end
    end
  end

  describe "when you implement a state with a handle_transition function" do
    test "it gets called by the outside module" do
      Undeferred.start_link(self())
      refute_receive _
      Process.sleep(100)
      assert_receive {:response, "foo"}
    end
  end
end
