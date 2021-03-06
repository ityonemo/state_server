defmodule StateServerTest.MultiverseTest do

  # tests to make sure we can imbue StateServer with
  # the ability to forward its caller.

  use Multiverses, with: DynamicSupervisor

  defmodule TestServer do
    use StateServer, on: []

    def start_link(opts) do
      StateServer.start_link(__MODULE__, nil, opts)
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call(:callers, _, _state, _data) do
      {:reply, Process.get(:"$callers")}
    end
  end

  use ExUnit.Case, async: true

  test "basic state_server caller functionality" do
    {:ok, srv} = TestServer.start_link(forward_callers: true)
    assert [self()] == GenServer.call(srv, :callers)
  end

  test "dynamically supervised StateServer gets correct caller" do
    {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)

    {:ok, child} = DynamicSupervisor.start_child(sup, {TestServer, [forward_callers: true]})

    Process.sleep(20)
    assert self() in GenServer.call(child, :callers)
  end

end
