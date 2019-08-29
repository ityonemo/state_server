defmodule StateServerTest.Callbacks.HandleInternalTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer

    @state_graph [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call(:go, _from, _state, _data) do
      {:reply, "foo", [internal: :foo]}
    end

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
end
