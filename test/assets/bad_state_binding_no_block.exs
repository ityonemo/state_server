defmodule BadStateBindingNoBlock do
  use StateServer, foo: []

  defstate External, for: :bar
end
