defmodule StateServerTest.Callbacks.HandleInternalTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call(:go, _from, _state, _data) do
      {:reply, "foo", [internal: :foo]}
    end

    @impl true
    def handle_internal(:foo, _state, fun), do: fun.()
  end

  describe "instrumenting handle_internal" do
    test "works with static/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn ->
        send(test_pid, :foobar)
        :noreply
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert_receive :foobar
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn ->
        send(test_pid, :foobar)
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn ->
        send(test_pid, :foobar)
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with transition/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn ->
        send(test_pid, :foobar)
        {:noreply, transition: :tr, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

  defmodule UnInstrumented do
    use StateServer, [start: [tr: :end], end: []]
    def start_link(_), do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(_), do: {:ok, :ok}

    @impl true
    def handle_call(:go, _, _, _) do
      {:reply, :ok, internal: "foo"}
    end
  end

  describe "tests against uninstrumented code" do
    test "should throw a runtime error" do
      Process.flag(:trap_exit, true)
      {:ok, srv} = UnInstrumented.start_link(:ok)
      StateServer.call(srv, :go)
      assert_receive {:EXIT, ^srv, {%RuntimeError{message: msg}, _}}
      assert msg =~ "handle_internal/3"
    end
  end
end
