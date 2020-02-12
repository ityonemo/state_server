defmodule StateServerTest.OnStateEntryTest do

  use ExUnit.Case, async: true

  defmodule Module do
    use StateServer, [start: [tr1: :end, tr2: :end, tr3: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    @impl true
    def handle_transition(_, :tr3, data) do
      {:noreply, update: Map.put(data, :updated, true)}
    end
    def handle_transition(_, _, _), do: :noreply

    @impl true
    def on_state_entry(nil, :end, %{pid: pid}) do
      send(pid, :end_via_goto)
      :noreply
    end
    def on_state_entry(_, :end, %{pid: pid, updated: true}) do
      send(pid, :transition_did_update)
      :noreply
    end
    def on_state_entry(trans, :end, %{pid: pid}) do
      send(pid, {:end_via_transition, trans})
      :noreply
    end
    def on_state_entry(_, _, _), do: :noreply

    @impl true
    def handle_cast(actions, _state, _data) do
      {:noreply, actions}
    end
  end

  describe "when making state changes" do
    test "a goto passes through on_state_entry with no transition declared." do
      {:ok, srv} = Module.start_link(%{pid: self()})
      GenServer.cast(srv, goto: :end)

      assert_receive :end_via_goto
    end

    test "a transition passes through on_state_entry with its transition declared (1)." do
      {:ok, srv} = Module.start_link(%{pid: self()})

      GenServer.cast(srv, transition: :tr1)

      assert_receive {:end_via_transition, :tr1}
    end

    test "a transition passes through on_state_entry with its transition declared (2)." do
      {:ok, srv} = Module.start_link(%{pid: self()})

      GenServer.cast(srv, transition: :tr2)

      assert_receive {:end_via_transition, :tr2}
    end

    test "a transition will correctly update for on_state_entry" do
      {:ok, srv} = Module.start_link(%{pid: self()})

      GenServer.cast(srv, transition: :tr3)

      assert_receive :transition_did_update
    end
  end

  defmodule EntryModule do
    use StateServer, start: [], unreachable: []

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data = %{goto: where}), do: {:ok, data, goto: where}
    def init(data), do: {:ok, data}

    @impl true
    def on_state_entry(tr, who, %{pid: pid}) do
      send(pid, {:entry, tr, who})
      :noreply
    end

    @impl true
    def handle_cast(actions, _state, _data) do
      {:noreply, actions}
    end
  end

  describe "on state_server initialization" do
    test "on_state_entry is with the starting state and nil as the transition" do
      EntryModule.start_link(%{pid: self()})

      assert_receive {:entry, nil, :start}
    end

    test "on_state_entry is called with the goto state" do
      EntryModule.start_link(%{pid: self(), goto: :unreachable})
      assert_receive {:entry, nil, :unreachable}
    end
  end
end
