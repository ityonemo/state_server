defmodule BadStateBinding do
  use StateServer, foo: []

  defstate Bar, for: :bar do
  end
end
