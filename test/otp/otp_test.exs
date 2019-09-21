defmodule StateServerTest.OtpTest do

  use ExUnit.Case, async: true

  # tests to see that OTP functionality is honored by our StateServer.

  defmodule TestServer do
    use StateServer, foo: []

    def start_link(opts), do: StateServer.start_link(__MODULE__, :ok, opts)

    @impl true
    def init(data), do: {:ok, data}

    def get_state(srv), do: GenServer.call(srv, :get_state)

    @impl true
    def handle_call(:get_state, _from, state, _data), do: {:reply, state}
  end

  defmodule TestServerOverridden do
    # override the child_spce to specify that we can kill something normally
    use StateServer, foo: []

    def start_link(opts), do: StateServer.start_link(__MODULE__, :ok, opts)

    def child_spec(arg, overrides) do
      super(arg, overrides ++ [restart: :transient])
    end

    @impl true
    def init(data), do: {:ok, data}

    def get_state(srv), do: GenServer.call(srv, :get_state)
    def stop(srv), do: GenServer.call(srv, :stop)

    @impl true
    def handle_call(:get_state, _from, state, _data), do: {:reply, state}
    def handle_call(:stop, from, _state, _data) do
      reply(from, :ok)
      {:stop, :normal, :ok}
    end

  end

  describe "you can make a supervised stateserver" do
    test "without implementing child_spec" do

      Supervisor.start_link([{TestServer, name: TestServer}], strategy: :one_for_one)

      Process.sleep(20)

      assert :foo == TestServer.get_state(TestServer)

      TestServer |> Process.whereis |> Process.exit(:normal)

      Process.sleep(20)

      assert :foo == TestServer.get_state(TestServer)
    end

    test "with overriding child_spec" do
      Supervisor.start_link([{TestServerOverridden, name: TestServer}], strategy: :one_for_one)

      Process.sleep(20)

      assert :foo == TestServerOverridden.get_state(TestServer)

      TestServer |> Process.whereis |> Process.exit(:kill)

      Process.sleep(20)

      assert :foo == TestServerOverridden.get_state(TestServer)

      TestServerOverridden.stop(TestServer)

      Process.sleep(20)

      refute Process.whereis(TestServer)
    end
  end

end
