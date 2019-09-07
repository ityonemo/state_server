defmodule StateServer.Macros do

  @moduledoc false

  defmacro default_handler([{name, arity}]) do
    generate_handler(name, arity)
  end

  @spec generate_handler(atom, non_neg_integer) :: Macro.t
  def generate_handler(name, arity) do
    fun = "#{name}/#{arity}"
    params = Enum.map(1..arity, fn _ -> {:_, [], Elixir} end)

    # block comes from GenServer implementation
    block = quote do
      proc = case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

      case :erlang.phash2(1, 1) do
        0 ->
          raise "attempted to call StateServer #{inspect(proc)} but no #{unquote(fun)} clause was provided"
        1 ->
          {:stop, {:EXIT, "call error"}}
      end
    end

    {:def,
      [context: __MODULE__, import: Kernel],
      [{name, [context: __MODULE__], params}, [do: block]]}
  end
end
