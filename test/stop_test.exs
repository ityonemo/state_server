defmodule StateServerTest.StopTest do
  # tests to make sure stop semantics are correct

  use ExUnit.Case, async: true

  @moduletag :stop_test

  defmodule Server do

    use StateServer, start: []

    def start(resp_pid), do: StateServer.start(__MODULE__, resp_pid)

    @impl true
    def init(resp_pid), do: {:ok, resp_pid}

    @impl true
    def handle_call(:stop2, from, _, _data) do
      StateServer.reply(from, :ok)
      {:stop, :normal}
    end
    def handle_call(:stop3, from, _, resp_pid) do
      StateServer.reply(from, :ok)
      {:stop, :normal, {:change, resp_pid}}
    end
    def handle_call(:stop4, _from, _, resp_pid) do
      {:stop, :normal, :ok, {:change, resp_pid}}
    end

    @impl true
    def handle_cast(:stop2, _, _data) do
      {:stop, :normal}
    end
    def handle_cast(:stop3, _, resp_pid) do
      {:stop, :normal, {:change, resp_pid}}
    end

    @impl true
    def terminate(_, _, {:change, resp_pid}) do
      send(resp_pid, :changed)
    end
  end

  describe "for handle_call" do
    test "the two-term reply works" do
      {:ok, srv} = Server.start(self())
      :ok = StateServer.call(srv, :stop2)
      Process.sleep(20)
      refute Process.alive?(srv)
    end

    test "the three-term reply works" do
      {:ok, srv} = Server.start(self())
      :ok = StateServer.call(srv, :stop3)
      assert_receive :changed
      Process.sleep(20)
      refute Process.alive?(srv)
    end

    test "the four-term reply works" do
      {:ok, srv} = Server.start(self())
      :ok = StateServer.call(srv, :stop4)
      assert_receive :changed
      Process.sleep(20)
      refute Process.alive?(srv)
    end
  end

  describe "for handle_cast" do
    test "the two-term reply works" do
      {:ok, srv} = Server.start(self())
      StateServer.cast(srv, :stop2)
      Process.sleep(20)
      refute Process.alive?(srv)
    end

    test "the three-term reply works" do
      {:ok, srv} = Server.start(self())
      StateServer.cast(srv, :stop3)
      assert_receive :changed
      Process.sleep(20)
      refute Process.alive?(srv)
    end
  end
end
