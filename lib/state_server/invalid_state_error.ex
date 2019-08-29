defmodule StateServer.InvalidStateError do

  @moduledoc "raised when you pass a funny atom to the `{:goto, _}` event"

  defexception [:message]
end
