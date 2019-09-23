defmodule StateServerTest.Callbacks.HandleTransitionTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do

    use StateServer, [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_transition(start_state, transition, fun) do
      fun.(start_state, transition)
    end

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call({:transition, tr}, _from, _state, _fun) do
      {:reply, "foo", transition: tr}
    end
    def handle_call({:transition_update, tr}, _from, _state, fun) do
      {:reply, "foo", transition: tr, update: fun}
    end
    def handle_call(:goto, _from, _state, _fun) do
      {:reply, "foo", goto: :end, update: "bar"}
    end

    @impl true
    def handle_cast({:transition, tr}, _state, _fun) do
      {:noreply, transition: tr}
    end
    def handle_cast({:transition_update, tr}, _state, fun) do
      {:noreply, transition: tr, update: fun}
    end
    def handle_cast({:delay, who}, _state, _data) do
      {:noreply, internal: {:delay, who}, transition: :tr}
    end

    @impl true
    def handle_internal({:delay, who}, _state, _data) do
      send(who, :deferral)
      receive do :deferred -> :noreply end
    end
  end

  test "a transition event triggers the transition" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :noreply
    end)

    assert {:start, f} = Instrumented.state(srv)

    StateServer.cast(srv, {:transition, :tr})

    assert_receive {:reply, :start, :tr}
  end

  test "a transition event with an update triggers the transition" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :noreply
    end)

    assert {:start, _f} = Instrumented.state(srv)

    StateServer.cast(srv, {:transition_update, :tr})

    assert_receive {:reply, :start, :tr}
  end

  test "a transition event in a call triggers the transition" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :noreply
    end)

    assert {:start, _f} = Instrumented.state(srv)

    assert "foo" == StateServer.call(srv, {:transition, :tr})

    assert_receive {:reply, :start, :tr}
  end

  test "a transition event in a call with an update triggers the transition" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :noreply
    end)

    assert {:start, _f} = Instrumented.state(srv)

    assert "foo" == StateServer.call(srv, {:transition_update, :tr})

    assert_receive {:reply, :start, :tr}
  end

  test "a deferred transition event triggers the transition" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :noreply
    end)

    assert {:start, _f} = Instrumented.state(srv)

    StateServer.cast(srv, {:delay, test_pid})
    receive do :deferral -> send(srv, :deferred) end

    assert_receive {:reply, :start, :tr}
  end

  test "a transition event can contain instructions in the payload" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      {:noreply, update: "foo"}
    end)

    assert {:start, _f} = Instrumented.state(srv)

    StateServer.cast(srv, {:transition, :tr})

    assert_receive {:reply, :start, :tr}

    assert {:end, "foo"} == Instrumented.state(srv)
  end

  test "a transition event can be cancelled" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      :cancel
    end)

    assert {:start, f} = Instrumented.state(srv)

    StateServer.cast(srv, {:delay, test_pid})
    receive do :deferral -> send(srv, :deferred) end

    assert_receive {:reply, :start, :tr}

    assert {:start, ^f} = Instrumented.state(srv)
  end

  test "a transition cancellation can contain instructions in the payload" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
      {:cancel, update: "foo"}
    end)

    assert {:start, _f} = Instrumented.state(srv)

    StateServer.cast(srv, {:transition, :tr})

    assert_receive {:reply, :start, :tr}

    assert {:start, "foo"} == Instrumented.state(srv)
  end

  test "a goto statement doesn't trigger transitioning" do
    test_pid = self()

    {:ok, srv} = Instrumented.start_link(fn state, tr ->
      send(test_pid, {:reply, state, tr})
    end)

    assert {:start, _f} = Instrumented.state(srv)

    assert "foo" == StateServer.call(srv, :goto)

    assert {:end, "bar"} == Instrumented.state(srv)

    refute_receive {:reply, _, _}
  end
end
