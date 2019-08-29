defmodule StateServer.InvalidTransitionError do

  @moduledoc "raised when you pass a funny atom to the `{:transition, _}` event"

  defexception [:message]
end
