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
      Registry.start_link(keys: :unique, name: "not_an_atom")
    end

    assert_raise ArgumentError, fn ->
      Registry.start_link(keys: :unique, name: {:foo, :bar})
    end
  end
end
