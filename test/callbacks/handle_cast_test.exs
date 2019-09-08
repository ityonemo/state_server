defmodule StateServerTest.Callbacks.HandleCastTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}

    @impl true
    def handle_cast(:go, _state, fun) when is_function(fun, 0), do: fun.()
  end

  describe "instrumenting handle_info" do
    test "works with static/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn -> :noreply end)
      assert {:start, f} = Instrumented.state(srv)
      StateServer.cast(srv, :go)
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      {:ok, srv} = Instrumented.start_link(fn -> {:noreply, update: "bar"} end)
      assert {:start, f} = Instrumented.state(srv)
      StateServer.cast(srv, :go)
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn -> {:noreply, transition: :tr} end)
      assert {:start, f} = Instrumented.state(srv)
      StateServer.cast(srv, :go)
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with transition/update" do
      {:ok, srv} = Instrumented.start_link(fn -> {:noreply, transition: :tr, update: "bar"} end)
      assert {:start, f} = Instrumented.state(srv)
      StateServer.cast(srv, :go)
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

  defmodule UnInstrumented do
    use StateServer, [start: [tr: :end], end: []]
    def start_link(_), do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(_), do: {:ok, :ok}
  end

  describe "tests against uninstrumented code" do
    test "should throw a runtime error" do
      Process.flag(:trap_exit, true)
      {:ok, srv} = UnInstrumented.start_link(:ok)
      StateServer.cast(srv, :foo)
      assert_receive {:EXIT, ^srv, {%RuntimeError{message: msg}, _}}
      assert msg =~ "handle_cast/3"
    end
  end
end
