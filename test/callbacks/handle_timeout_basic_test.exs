defmodule StateServerTest.Callbacks.HandleTimeoutBasicTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)
    def named_timeout(srv, time \\ 0), do: StateServer.call(srv, {:named_timeout, time})
    def named_timeout_payload(srv, time \\ 0, payload) do
      StateServer.call(srv, {:named_timeout, payload, time})
    end
    def unnamed_timeout(srv), do: StateServer.call(srv, :unnamed_timeout)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:named_timeout, time}, _from, _state, _data) do
      {:reply, "foo", [timeout: {:bar, time}]}
    end
    def handle_call({:named_timeout, payload, time}, _from, _state, _data) do
      {:reply, "foo", [timeout: {:bar, payload, time}]}
    end
    def handle_call(:unnamed_timeout, _from, _state, _data) do
      {:reply, "foo", [timeout: 10]}
    end

    @impl true
    def handle_timeout(value, _state, fun), do: fun.(value)
  end

  describe "instrumenting handle_timeout and triggering with unnamed_timeout" do
    test "works, submitting nil" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.unnamed_timeout(srv)

      assert_receive {:foo, nil}
    end

    test "is not interrupted" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.unnamed_timeout(srv)

      assert {:start, _} = Instrumented.state(srv)

      assert_receive {:foo, nil}

      assert {:start, "bar"} == Instrumented.state(srv)
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

      {:ok, srv} = Instrumented.start_link(fn value ->
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

  defmodule UnInstrumented do
    use StateServer, [start: [tr: :end], end: []]
    def start_link(_), do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(_), do: {:ok, :ok}

    @impl true
    def handle_call(:go, _, _, _) do
      {:reply, :ok, timeout: 50}
    end
  end

  describe "tests against uninstrumented code" do
    test "should throw a runtime error" do
      Process.flag(:trap_exit, true)
      {:ok, srv} = UnInstrumented.start_link(:ok)
      StateServer.call(srv, :go)
      assert_receive {:EXIT, ^srv, {%RuntimeError{message: msg}, _}}
      assert msg =~ "handle_timeout/3"
    end
  end
end
