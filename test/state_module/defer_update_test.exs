
defmodule StateServerTest.StateModule.DeferUpdateTest do

  use ExUnit.Case, async: true

  defmodule Instrumentable do
    use StateServer, [start: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def run_call(srv, msg), do: GenServer.call(srv, {:run, msg})
    def run_cast(srv, msg), do: GenServer.cast(srv, {:run, self(), msg})

    def data(srv), do: GenServer.call(srv, :data)

    @impl true
    def handle_call({:run, msg}, _from, _state, _data), do: msg
    def handle_call(:data, _from, _state, data), do: {:reply, data}

    @impl true
    def handle_cast({:run, _from, msg}, _state, _data), do: msg

    defstate Start, for: :start do
      @impl true
      def handle_call(_, _from, inner_data) do
        {:reply, inner_data}
      end

      @impl true
      def handle_cast({_, from, _}, inner_data) do
        send(from, inner_data)
        :noreply
      end
    end
  end

  describe "when you defer with an update" do
    test "in the first position with call, it shows up in the data" do
      {:ok, srv} = Instrumentable.start_link(:foo)
      assert :foo == Instrumentable.data(srv)
      assert :bar == Instrumentable.run_call(srv, {:defer, update: :bar})
      assert :bar == Instrumentable.data(srv)
    end

    test "in the first position with cast, it shows up in the data" do
      {:ok, srv} = Instrumentable.start_link(:foo)
      assert :foo == Instrumentable.data(srv)
      Instrumentable.run_cast(srv, {:defer, update: :bar})
      assert_receive :bar
      assert :bar == Instrumentable.data(srv)
    end

    test "in the first position with call/goto, it shows up in the data" do
      {:ok, srv} = Instrumentable.start_link(:foo)
      assert :foo == Instrumentable.data(srv)
      assert :bar == Instrumentable.run_call(srv, {:defer, goto: :start, update: :bar})
      assert :bar == Instrumentable.data(srv)
    end

    test "in the first position with cast/goto, it shows up in the data" do
      {:ok, srv} = Instrumentable.start_link(:foo)
      assert :foo == Instrumentable.data(srv)
      Instrumentable.run_cast(srv, {:defer, goto: :start, update: :bar})
      assert_receive :bar
      assert :bar == Instrumentable.data(srv)
    end
  end

end
