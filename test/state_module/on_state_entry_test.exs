defmodule StateServerTest.StateModule.OnStateEntryTest do

  use ExUnit.Case, async: true

  defmodule StateEntry do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    @impl true
    def handle_call(action, _from, _state, _data), do: {:reply, :ok, action}

    @impl true
    def on_state_entry(_, :start, _), do: :noreply
    defer on_state_entry

    defstate End, for: :end do
      @impl true
      def on_state_entry(trans, resp_pid) do
        send(resp_pid, {:entry_via, trans})
        :noreply
      end
    end

  end

  describe "when you implement a state with a on_state_entry function" do
    test "it gets called correctly when transitioning" do
      {:ok, pid} = StateEntry.start_link(self())
      GenServer.call(pid, transition: :tr)
      assert_receive {:entry_via, :tr}
    end

    test "it gets called correctly on goto" do
      {:ok, pid} = StateEntry.start_link(self())
      GenServer.call(pid, goto: :end)
      assert_receive {:entry_via, nil}
    end
  end

  defmodule StateEntryDeferral do
    use StateServer, [start: [tr: :end, tr2: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    @impl true
    def handle_call(action, _from, _state, _data), do: {:reply, :ok, action}

    @impl true
    def on_state_entry(:tr2, :end, data) do
      send(data, :outer_handler)
      :noreply
    end
    def on_state_entry(_, :start, _), do: :noreply
    defer on_state_entry

    defstate End, for: :end do
      @impl true
      def on_state_entry(trans, resp_pid) do
        send(resp_pid, {:entry_via, trans})
        :noreply
      end
    end

  end

  describe "when you implement a state with a on_state_entry function and defer" do
    test "it gets called correctly after deferral" do
      {:ok, pid} = StateEntryDeferral.start_link(self())
      GenServer.call(pid, transition: :tr)
      assert_receive {:entry_via, :tr}
    end

    test "it gets called correctly before deferral" do
      {:ok, pid} = StateEntryDeferral.start_link(self())
      GenServer.call(pid, transition: :tr2)
      assert_receive :outer_handler
    end

    test "it gets called correctly on goto" do
      {:ok, pid} = StateEntryDeferral.start_link(self())
      GenServer.call(pid, goto: :end)
      assert_receive {:entry_via, nil}
    end
  end
end
