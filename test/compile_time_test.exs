defmodule StateServerTest.CompileTimeTest do
  use ExUnit.Case, async: true

  alias StateServer.StateGraph

  test "not defining your state_graph causes a compile time error" do
    assert_raise ArgumentError, fn -> Code.require_file("test/assets/use_without_graph.exs") end
  end

  test "assigning state_graph causes a compile time error" do
    assert_raise CompileError, fn -> Code.require_file("test/assets/malformed_graph.exs") end
  end

  defmodule GraphFunction do
    use StateServer, state_graph: [foo: [bar: :foo]]

    @impl true
    def init(_), do: {:ok, :ok}
  end

  test "__state_graph__/0 is correctly assigned at compile time" do
    assert [foo: [bar: :foo]] == GraphFunction.__state_graph__()
  end

  test "state typelists are generated correctly" do
    singleton_state = StateGraph.atoms_to_typelist([:foo])
    q1 = quote do @type state :: :foo end
    q2 = quote do @type state :: unquote(singleton_state) end

    assert q1 == q2

    two_states = StateGraph.atoms_to_typelist([:foo, :bar])
    q3 = quote do @type state :: :foo | :bar end
    q4 = quote do @type state :: unquote(two_states) end

    assert q3 == q4

    three_states = StateGraph.atoms_to_typelist([:foo, :bar, :baz])
    q5 = quote do @type state :: :foo | :bar | :baz end
    q6 = quote do @type state :: unquote(three_states) end

    assert q5 == q6
  end
end
