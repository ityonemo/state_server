defmodule StateServerTest.StateModule.OnStateEntryTest do

  use ExUnit.Case, async: true

  defmodule StateEntry do
    use StateServer, [start: [tr: :end, tr_trap: :end, tr_double: :end, tr_update: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    @impl true
    def handle_call(action, _from, _state, _data), do: {:reply, :ok, action}

    @impl true
    def handle_transition(:start, :tr_update, pid) do
      # do a transition which will modify the state
      {:noreply, update: {:update, pid}}
    end
    def handle_transition(_, _, _), do: :noreply

    @impl true
    def on_state_entry(:tr_trap, :end, pid) do
      # traps the state_entry early and doesn't fall through to
      # the state module.
      send(pid, :trapped_route)
      :noreply
    end
    def on_state_entry(:tr_double, :end, pid) do
      # allows for a double-hit
      send(pid, :first_hit)
      :defer
    end
    def on_state_entry(_, :start, _), do: :noreply
    defer on_state_entry

    defstate End, for: :end do
      @impl true
      def on_state_entry(_, {:update, resp_pid}) do
        send(resp_pid, :update_verified)
        :noreply
      end
      def on_state_entry(:tr_double, resp_pid) do
        send(resp_pid, :second_hit)
        :noreply
      end
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

    test "you can still trap special cases" do
      {:ok, pid} = StateEntry.start_link(self())
      GenServer.call(pid, transition: :tr_trap)
      assert_receive :trapped_route
    end

    test "double hits must be explicit" do
      {:ok, pid} = StateEntry.start_link(self())
      GenServer.call(pid, transition: :tr_double)
      assert_receive :first_hit
      assert_receive :second_hit
    end

    test "you can trigger an update" do
      {:ok, pid} = StateEntry.start_link(self())
      GenServer.call(pid, transition: :tr_update)
      assert_receive :update_verified
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
