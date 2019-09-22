defmodule StateServerTest.StateModule.HandleInternalTest do

  use ExUnit.Case, async: true

  # TODO: change the names of all of these from "Instrumented"

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data, internal: :internal_msg}

    defstate Start, for: :start do
      @impl true
      def handle_internal(:internal_msg, resp_pid) do
        send(resp_pid, {:response, "foo"})
        :noreply
      end
    end
  end

  describe "when you implement a state with a handle_internal function" do
    test "it gets called by the outside module" do
      Instrumented.start_link(self())
      assert_receive {:response, "foo"}
    end
  end
end
