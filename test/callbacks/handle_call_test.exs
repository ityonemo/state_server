# TODO: make sure that the call scheme is well tested

defmodule StateServerTest.Callbacks.HandleCallTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, state_graph: [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: {:ok, fun}

    def state(srv), do: StateServer.call(srv, :state)

    @impl true
    def handle_call(:state, _from, state, data), do: {:reply, {state, data}}
    def handle_call(:go, _from, _state, fun) when is_function(fun, 0), do: fun.()
    def handle_call(:go, from, _state, fun) when is_function(fun, 1), do: fun.(from)

    @impl true
    def handle_info({:do_reply, from}, _state, _val) do
      reply(from, "foo")
      :noreply
    end
  end

  describe "instrumenting handle_call with reply" do
    test "works with static/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn -> {:reply, "foo"} end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      {:ok, srv} = Instrumented.start_link(fn -> {:reply, "foo", update: "bar"} end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn -> {:reply, "foo", transition: :tr} end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with transition/update" do
      {:ok, srv} = Instrumented.start_link(fn -> {:reply, "foo", transition: :tr, update: "bar"} end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

  describe "instrumenting handle_call with deferred reply using Process.send_after" do
    test "works with static/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn from ->
        Process.send_after(self(), {:do_reply, from}, 0)
        :noreply
      end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:start, ^f} = Instrumented.state(srv)
    end

    test "works with static/update" do
      {:ok, srv} = Instrumented.start_link(fn from ->
        Process.send_after(self(), {:do_reply, from}, 0)
        {:noreply, update: "bar"}
      end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:start, "bar"} = Instrumented.state(srv)
    end

    test "works with transition/idempotent" do
      {:ok, srv} = Instrumented.start_link(fn from ->
        Process.send_after(self(), {:do_reply, from}, 0)
        {:noreply, transition: :tr}
      end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, ^f} = Instrumented.state(srv)
    end

    test "works with transition/update" do
      {:ok, srv} = Instrumented.start_link(fn from ->
        Process.send_after(self(), {:do_reply, from}, 0)
        {:noreply, transition: :tr, update: "bar"}
      end)
      assert {:start, f} = Instrumented.state(srv)
      assert "foo" = StateServer.call(srv, :go)
      assert {:end, "bar"} = Instrumented.state(srv)
    end
  end

  defmodule UnInstrumented do
    use StateServer, state_graph: [start: [tr: :end], end: []]
    def start_link(_), do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(_), do: {:ok, :ok}
  end

  describe "tests against uninstrumented code" do
    test "should throw a runtime error" do
      Process.flag(:trap_exit, true)
      {:ok, srv} = UnInstrumented.start_link(:ok)
      emsg = catch_exit(StateServer.call(srv, :foo))
      assert {{%RuntimeError{message: msg}, _}, _} = emsg
      assert msg =~ "handle_call/4"
    end
  end
end
