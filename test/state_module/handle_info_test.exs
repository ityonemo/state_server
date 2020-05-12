defmodule StateServerTest.StateModule.HandleInfoTest do

  use ExUnit.Case, async: true

  defmodule Undelegated do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def send_cast(srv), do: GenServer.cast(srv, {:send_cast, self()})

    defstate Start, for: :start do
      @impl true
      def handle_info({:respond, from}, data) do
        send(from, {:response, data})
        :noreply
      end
    end
  end

  defmodule Delegated do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def send_cast(srv), do: GenServer.cast(srv, {:send_cast, self()})

    delegate handle_info

    defstate Start, for: :start do
      @impl true
      def handle_info({:respond, from}, data) do
        send(from, {:response, data})
        :noreply
      end
    end
  end

  describe "when you implement a state with a handle_info function" do
    test "it gets called by the outside module" do
      {:ok, pid} = Undelegated.start_link("foo")

      send(pid, {:respond, self()})
      assert_receive {:response, "foo"}
    end

    test "it can get called when delegated" do
      {:ok, pid} = Delegated.start_link("foo")

      send(pid, {:respond, self()})
      assert_receive {:response, "foo"}
    end
  end
end
