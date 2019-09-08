defmodule StateServerTest.Callbacks.HandleTimeoutEventTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)
    def event_timeout(srv, time \\ 0) do
      StateServer.call(srv, {:event_timeout, time})
    end
    def event_timeout_payload(srv, time \\ 0, payload) do
      StateServer.call(srv, {:event_timeout, time, payload})
    end

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:event_timeout, time}, _from, _state, _data) do
      {:reply, "foo", [event_timeout: time]}
    end
    def handle_call({:event_timeout, time, payload}, _from, _state, _data) do
      {:reply, "foo", [event_timeout: {payload, time}]}
    end

    @impl true
    def handle_timeout(value, _state, fun), do: fun.(value)
  end

  describe "instrumenting handle_timeout and triggering with event_timeout" do
    test "works with static/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        :noreply
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout(srv)
      assert_receive {:foo, nil}
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout(srv)
      assert_receive {:foo, nil}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout(srv)
      assert_receive {:foo, nil}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent, interruptible" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout(srv, 10)

      # interrupt the event timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:start, ^f} = Instrumented.state(srv)

      # let's be sure that we don't get the expected response
      refute_receive _

      assert "foo" = Instrumented.event_timeout(srv, 10)
      assert_receive {:foo, nil}
    end

    test "works with transition/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout(srv)
      assert_receive {:foo, nil}
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

  describe "instrumenting handle_timeout and triggering with event_timeout and payload" do
    test "works with static/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        :noreply
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with delayed transition/idempotent" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout_payload(srv, 10, :payload)

      # interrupt the event timeout
      Process.sleep(5)
      assert {:start, ^f} = Instrumented.state(srv)
      Process.sleep(10)
      assert {:start, ^f} = Instrumented.state(srv)

      # let's be sure that we don't get the expected response
      refute_receive _

      assert "foo" = Instrumented.event_timeout_payload(srv, 10, :payload)
      assert_receive {:foo, :payload}
    end

    test "works with transition/update" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, transition: :tr, update: "bar"}
      end)

      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = Instrumented.event_timeout_payload(srv, :payload)
      assert_receive {:foo, :payload}
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

end
