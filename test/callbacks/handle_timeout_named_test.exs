defmodule StateServerTest.Callbacks.HandleTimeoutNamedTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer

    @state_graph [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)
    def named_timeout(srv, time \\ 0), do: StateServer.call(srv, {:named_timeout, time})
    def named_timeout_payload(srv, time \\ 0, payload) do
      StateServer.call(srv, {:named_timeout, payload, time})
    end

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:named_timeout, time}, _from, _state, _data) do
      {:reply, "foo", [timeout: {:bar, time}]}
    end
    def handle_call({:named_timeout, payload, time}, _from, _state, _data) do
      {:reply, "foo", [timeout: {:bar, payload, time}]}
    end

    @impl true
    def handle_timeout(value, _state, fun), do: fun.(value)
  end

  describe "instrumenting handle_timeout and triggering with named_timeout" do
    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout(srv)
      assert_receive {:foo, :bar}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout(srv)
      assert_receive {:foo, :bar}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout(srv, 10)

      # calls don't interrupt the named timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:end, ^f} = Instrumented.state(srv)

      # let's be sure that we have gotten the expected response
      assert_receive {:foo, :bar}
    end
  end

  describe "instrumenting handle_timeout and triggering with timeout and payload" do
    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout_payload(srv, :payload)
      assert_receive {:foo, {:bar, :payload}}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout_payload(srv, :payload)
      assert_receive {:foo, {:bar, :payload}}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.named_timeout_payload(srv, 10, :payload)

      # calls don't interrupt the named timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:end, ^f} = Instrumented.state(srv)

      # let's be sure that we have gotten the expected response
      assert_receive {:foo, {:bar, :payload}}
    end
  end
end
