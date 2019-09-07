defmodule StateServerTest.Macros.GenerateHandlerTest do
  use ExUnit.Case, async: true

  alias StateServer.Macros

  test "generate_handler snapshot" do
    assert (~S"""
    @doc false
    def handle_foo(_, _) do
      proc = case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

      case :erlang.phash2(1, 1) do
        0 ->
          raise "attempted to call StateServer #{inspect(proc)} but no #{"handle_foo/2"} clause was provided"
        1 ->
          {:stop, {:EXIT, "call error"}}
      end
    end
    """
    |> Code.string_to_quoted!
    |> Macro.to_string) == (
      Macro.to_string(Macros.generate_handler(:handle_foo, 2)))
  end
end
