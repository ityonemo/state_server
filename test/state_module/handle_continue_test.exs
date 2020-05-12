defmodule StateServerTest.StateModule.HandleContinueTest do

  use ExUnit.Case, async: true

  defmodule Undelegated do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data, continue: :my_continuation}

    defstate Start, for: :start do
      @impl true
      def handle_continue(:my_continuation, resp_pid) do
        send(resp_pid, {:response, "foo"})
        :noreply
      end
    end
  end

  defmodule Delegated do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data, continue: :my_continuation}

    delegate handle_continue

    defstate Start, for: :start do
      @impl true
      def handle_continue(:my_continuation, resp_pid) do
        send(resp_pid, {:response, "foo"})
        :noreply
      end
    end
  end

  describe "when you implement a state with a handle_continue function" do
    test "it gets called by the outside module" do
      Undelegated.start_link(self())
      assert_receive {:response, "foo"}
    end

    test "it can get called when delegated" do
      Delegated.start_link(self())
      assert_receive {:response, "foo"}
    end
  end
end
