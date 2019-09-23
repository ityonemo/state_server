defmodule ExternalStart do
  def handle_call(:get_data, _from, data) do
    {:reply, data}
  end
end

defmodule StateServerTest.StateModule.BasicTest do

  use ExUnit.Case, async: true

  defmodule Basic do
    use StateServer, [start: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def get_data(srv), do: GenServer.call(srv, :get_data)

    defstate Start, for: :start do
    end
  end

  describe "when you use defstate/3" do
    test "it creates a submodule" do
      assert function_exported?(Basic.Start, :__info__, 1)
    end
  end

  defmodule WithoutBlock do
    use StateServer, [start: []]

    def start_link(data), do: StateServer.start_link(__MODULE__, data)

    @impl true
    def init(data), do: {:ok, data}

    def get_data(srv), do: GenServer.call(srv, :get_data)

    defstate ExternalStart, for: :start
  end

  describe "when you use defstate without a block" do
    test "you can still get it to work" do
      {:ok, pid} = WithoutBlock.start_link("foo")
      assert "foo" == WithoutBlock.get_data(pid)
    end
  end

end
