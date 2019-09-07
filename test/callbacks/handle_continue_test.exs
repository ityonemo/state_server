defmodule StateServerTest.Callbacks.HandleContinueTest do

  use ExUnit.Case, async: true

  defmodule Instrumented do
    use StateServer, state_graph: [start: [tr: :end], end: []]

    def start_link(fun), do: StateServer.start_link(__MODULE__, fun)

    @impl true
    def init(fun), do: fun.()

    @impl true
    def handle_continue(:continuation, _state, fun), do: fun.()

    @impl true
    def handle_call(:call, _from, _state, _fun) do
      {:reply, :ok, continue: :continuation}
    end
  end

  describe "instrumenting handle_continue" do
    test "works from the init function" do
      test_pid = self()

      internal_function = fn ->
        receive do :unblock -> :ok end
        send(test_pid, :initialized)
      end

      {:ok, pid} = Instrumented.start_link(fn ->
        {:ok, internal_function, continue: :continuation}
      end)

      refute_receive :initialized
      send(pid, :unblock)
      assert_receive :initialized
    end

    test "works from a generic call function" do
      test_pid = self()

      internal_function = fn ->
        receive do :unblock -> :ok end
        send(test_pid, :continued)
      end

      {:ok, pid} = Instrumented.start_link(fn ->
        {:ok, internal_function}
      end)

      assert :ok == GenServer.call(pid, :call)

      refute_receive :continued
      send(pid, :unblock)
      assert_receive :continued
    end
  end

  defmodule UnInstrumented do
    use StateServer, state_graph: [start: [tr: :end], end: []]
    def start_link(_), do: StateServer.start_link(__MODULE__, :ok)

    @impl true
    def init(_), do: {:ok, :ok}

    @impl true
    def handle_call(:go, _, _, _) do
      {:reply, :ok, continue: "foo"}
    end
  end

  describe "tests against uninstrumented code" do
    test "should throw a runtime error" do
      Process.flag(:trap_exit, true)
      {:ok, srv} = UnInstrumented.start_link(:ok)
      StateServer.call(srv, :go)
      assert_receive {:EXIT, ^srv, {%RuntimeError{message: msg}, _}}
      assert msg =~ "handle_continue/3"
    end
  end

end
