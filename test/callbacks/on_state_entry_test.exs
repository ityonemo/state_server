defmodule StateServerTest.OnStateEntryTest do

  use ExUnit.Case, async: true

  defmodule Module do
    use StateServer, [start: [tr1: :end, tr2: :end], end: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    @impl true
    def on_state_entry(:end, nil, %{pid: pid}) do
      send(pid, :end_via_goto)
      :noreply
    end
    def on_state_entry(:end, trans, %{pid: pid}) do
      send(pid, {:end_via_transition, trans})
      :noreply
    end

    @impl true
    def handle_cast({:goto, new_state}, _state, _data) do
      {:noreply, goto: new_state}
    end
  end

  describe "when making state changes" do
    test "a goto passes through on_state_entry with no transition declared." do
      {:ok, srv} = Module.start_link(%{pid: self()})
      GenServer.cast(srv, {:goto, :end})

      assert_receive :end_via_goto
    end
  end
end
