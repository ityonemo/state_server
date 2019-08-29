defmodule R do
  defmacro x(t) do
    IO.inspect(t)
    quote do end
  end
end

defmodule S do
  import R
  R.x(def yo(x) when x == 2, do: x)
  R.x(def yo(x), do: x)
end
