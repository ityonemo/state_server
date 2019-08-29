defmodule StateServerTest.Callbacks.HandleTimeoutStateTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer

    @state_graph [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)
    def state_timeout(srv, time \\ 0), do: StateServer.call(srv, {:state_timeout, time})
    def state_timeout_payload(srv, time \\ 0, payload) do
      StateServer.call(srv, {:state_timeout, payload, time})
    end

    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:state_timeout, time}, _from, _state, _data) do
      {:reply, "foo", state_timeout: time}
    end
    def handle_call({:state_timeout, payload, time}, _from, _state, _data) do
      {:reply, "foo", state_timeout: {payload, time}}
    end
    def handle_call({:transition, tr}, _from, _state, _data) do
      {:reply, :ok, transition: tr}
    end

    def handle_timeout(value, _state, fun), do: fun.(value)
  end

  describe "instrumenting handle_timeout and triggering with state_timeout" do
    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout(srv)
      assert_receive {:foo, 0}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout(srv)
      assert_receive {:foo, 0}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout(srv, 10)

      # calls don't interrupt the named timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:start, "bar"} = Instrumented.state(srv)

      # let's be sure that we have gotten the expected response
      assert_receive {:foo, 10}
    end

    test "is interruptible with state change" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout(srv, 10)

      Process.sleep(5)
      # state changes can interrupt the timeout
      StateServer.call(srv, {:transition, :tr})

      Process.sleep(10)
      assert {:end, ^f} = Instrumented.state(srv)

      # let's be sure that we have never gotten the expected response
      refute_receive {:foo, _}
    end
  end

  describe "instrumenting handle_timeout and triggering with state_timeout and payload" do
    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout_payload(srv, 10, :payload)

      # calls don't interrupt the named timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:start, "bar"} = Instrumented.state(srv)

      # let's be sure that we have gotten the expected response
      assert_receive {:foo, :payload}
    end

    test "state changes can interrupt the timeout" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.state_timeout_payload(srv, 10, :payload)

      # state changes can interrupt the timeout.
      Process.sleep(5)
      StateServer.call(srv, {:transition, :tr})

      Process.sleep(10)
      assert {:end, ^f} = Instrumented.state(srv)

      # let's be sure that we have not gotten the expected response
      refute_receive {:foo, _}
    end
  end
end
