defmodule StateServerTest.Callbacks.HandleTimeoutErlangTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)
    def timeout(srv, sig), do: StateServer.call(srv, {:timeout, sig})

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:timeout, signature}, from, _state, _data) do
      {:keep_state_and_data, [{:reply, from, :ok}, signature]}
    end

    @impl true
    def handle_timeout(value, _state, fun), do: fun.(value)
  end

  describe "instrumenting handle_timeout and triggering with erlang event_timeout" do
    test "works, with naked timeout, submitting nil" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.timeout(srv, 10)

      assert_receive {:foo, nil}
    end

    test "works with event timeout, and payload" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.timeout(srv, {:timeout, 10, "bar"})

      assert_receive {:foo, "bar"}
    end
  end

  describe "instrumenting handle_timeout and triggering with erlang named_timeout" do
    test "works with named timeout, with payload" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.timeout(srv, {{:timeout, :foo}, 10, "bar"})

      assert_receive {:foo, "bar"}
    end
  end

  describe "instrumenting handle_timeout and triggering with erlang state_timeout" do
    test "works with state timeout, with payload" do
      test_pid = self()

      {:ok, srv} = Instrumented.start_link(fn value ->
        send(test_pid, {:foo, value})
        {:noreply, update: "bar"}
      end)

      Instrumented.timeout(srv, {:state_timeout, 10, "bar"})

      assert_receive {:foo, "bar"}
    end
  end
end
