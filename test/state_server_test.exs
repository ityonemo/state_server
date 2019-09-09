defmodule StateServerTest do
  #
  # tests relating to starting a StateServer startup
  #

  use ExUnit.Case, async: true

  defmodule Startup do
    use StateServer, [start: []]

    def start_link(data, opts \\ []) do
      StateServer.start_link(__MODULE__, data, opts)
    end

    @impl true
    def init(data), do: {:ok, data}

    @spec dump(StateServer.server()) :: {atom, any}
    def dump(srv), do: StateServer.call(srv, :dump)

    @spec dump_impl(any, any) :: {:reply, {atom, any}}
    defp dump_impl(state, data), do: {:reply, {state, data}}

    @impl true
    def handle_call(:dump, _from, state, data), do: dump_impl(state, data)
  end

  test "starting a StateServer starts with the expected transition" do
    {:ok, pid} = Startup.start_link("foo")
    assert {:start, "foo"} == Startup.dump(pid)
  end

  test "starting a StateServer as locally named works" do
    {:ok, _} = Startup.start_link("foo", name: TestServer)
    assert {:start, "foo"} == Startup.dump(TestServer)
  end

  test "starting a StateServer as globally named works" do
    {:ok, _} = Startup.start_link("foo", name: {:global, TestServer2})
    assert {:start, "foo"} == Startup.dump({:global, TestServer2})
  end

  test "starting a registered StateServer works" do
    Registry.start_link(keys: :unique, name: TestRegistry)

    {:ok, _} = Startup.start_link("foo", name: {:via, Registry, {TestRegistry, :foo}})
    assert {:start, "foo"} == Startup.dump({:via, Registry, {TestRegistry, :foo}})
  end

  test "raises with a strange name entry" do
    assert_raise ArgumentError, fn ->
      Startup.start_link("foo", name: "not_an_atom")
    end

    assert_raise ArgumentError, fn ->
      Startup.start_link("foo", name: {:foo, :bar})
    end
  end

  defmodule StartupInstrumentable do
    use StateServer, [start: [], end: []]

    def start_link(fun, opts \\ []) do
      StateServer.start_link(__MODULE__, fun, opts)
    end

    @impl true
    def init(fun), do: fun.()

    @impl true
    def handle_internal(:foo, _state, test_pid) do
      send(test_pid, :inside)
      :noreply
    end

    @impl true
    def handle_continue(:foo, _state, test_pid) do
      send(test_pid, :continue)
      :noreply
    end

    @impl true
    def handle_call(:state, _from, state, _), do: {:reply, state}
  end

  test "StateServer started with :ignore can ignore" do
    assert :ignore = StartupInstrumentable.start_link(fn -> :ignore end)
  end

  test "StateServer started with {:stop, reason} returns the error" do
    assert {:error, :critical} = StartupInstrumentable.start_link(fn
      -> {:stop, :critical}
    end)
  end

  test "StateServer started with internal message executes it" do
    test_pid = self()
    StartupInstrumentable.start_link(fn -> {:ok, test_pid, internal: :foo} end)
    assert_receive(:inside)
  end

  test "StateServer started with goto sets state" do
    test_pid = self()
    {:ok, pid} = StartupInstrumentable.start_link(fn -> {:ok, test_pid, goto: :end} end)
    assert :end == StateServer.call(pid, :state)
  end

  test "StateServer started with goto and a continuation sets state" do
    test_pid = self()
    {:ok, pid} = StartupInstrumentable.start_link(fn -> {:ok, test_pid, goto: :end, continue: :foo} end)
    assert_receive(:continue)
    assert :end == StateServer.call(pid, :state)
  end

  test "StateServer started with goto and internal sets state correctly" do
    test_pid = self()
    {:ok, pid} = StartupInstrumentable.start_link(fn -> {:ok, test_pid, goto: :end, internal: :foo} end)
    assert_receive(:inside)
    assert :end == StateServer.call(pid, :state)
  end
end
