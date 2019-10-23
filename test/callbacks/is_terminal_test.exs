defmodule StateServerTest.Callbacks.IsTerminalTest do

  use ExUnit.Case, async: true

  defmodule Module do
    use StateServer, [start: [tr1: :end, tr2: :start], end: []]

    def test_terminal(state) when is_terminal(state), do: :terminal
    def test_terminal(_state), do: :not_terminal

    def test_terminal(state, transition) when is_terminal(state, transition), do: :terminal
    def test_terminal(_state, _transition), do: :not_terminal

    @impl true
    def init(_), do: {:ok, :ok}
  end

  test "is_terminal/1 can guard successfully for states" do
    assert :not_terminal == Module.test_terminal(:start)
    assert :terminal == Module.test_terminal(:end)
  end

  test "is_terminal/2 can guard successfully for state/transitions" do
    assert :not_terminal == Module.test_terminal(:start, :tr2)
    assert :terminal == Module.test_terminal(:start, :tr1)
  end

  test "is_terminal/1 works externally" do
    import Module

    refute is_terminal(:start)
    assert is_terminal(:end)
  end

  test "is_terminal/2 works externally" do
    import Module

    refute is_terminal(:start, :tr2)
    assert is_terminal(:start, :tr1)
  end

end
