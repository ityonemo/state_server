defmodule StateServerTest.StateModule.HandleCallTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def get_data(srv), do: GenServer.call(srv, :get_data)

    defstate Start, for: :start do
      @impl true
      def handle_call(:get_data, _from, data) do
        {:reply, data}
      end
    end
  end

  describe "when you implement a state with a handle_call function" do
    test "it gets called by the outside module" do
      {:ok, pid} = Instrumented.start_link("foo")

      assert "foo" == Instrumented.get_data(pid)
    end
  end
end
