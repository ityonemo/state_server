defmodule StateServer.State do

  @state_server_with_states_code File.read!("example/switch_with_states.exs")

  @moduledoc """
  A behaviour that lets you organize code for your `StateServer` states.

  ## Organization

  When you define your `StateServer`, the `StateServer` module gives you the
  opportunity to define **state modules**.  These are typically (but not
  necessarily) submodules scoped under the main `StateServer` module.  In
  this way, your code for handling events can be neatly organized by
  state.  In some (but not all) cases, this may be the most appropriate
  way to keep your state machine codebase sane.

  ### Defining the state module.

  the basic syntax for defining a state module is as follows:

  ```elixir
  defstate MyModule, for: :state do
    # ... code goes here ...

    def handle_call(:increment, _from, data) do
      {:reply, :ok, update: data + 1}
    end
  end
  ```

  note that the callback directives defined in this module are identical
  to those of `StateServer`, except that they are missing the `state` argument.

  ### External state modules

  You might want to use an external module to handle event processing for
  one your state machine.  Reasons might include:

  - to enable code reuse between state machines
  - if your codebase is getting too long and you would like to put state modules
    in different files.

  If you choose to do so, there is a **short form** `defstate` call, which is as
  follows:

  ```elixir
  defstate ExternalModule, for: :state
  ```

  ### Precedence and Defer statements

  Note that `handle_\*` functions written directly in the body of the `StateServer`
  take precedence over any functions written as a part of a state module.  In the
  case where there are competing function calls, your handler functions written
  *in the body* of the `StateServer` may emit `:defer` as a result, which will punt
  the processing of the event to the state modules.

  ```elixir
  # make sure query calls happen regardless of state
  def handle_call(:query, _from, _state, data) do
    {:reply, {state, data}}
  end
  # for all other call payloads, send to the state modules
  def handle_call(_, _, _, _) do
    :defer
  end

  defstate Start, for: :start do
    def handle_call(...) do...
  ```

  since this is a common pattern, we provide a `defer` macro which is equivalent
  to the above.

  ```elixir
  # make sure query calls happen regardless of state
  def handle_call(:query, _from, _state, data) do
    {:reply, {state, data}}
  end
  # for all other call payloads, send to the state modules
  defer handle_call
  ```

  You do not need this pattern for event handlers which are not implemented in
  the body of the function.

  ## Example

  The following code should produce a "light switch" state server that
  announces when it's been flipped.

  ```elixir
  #{@state_server_with_states_code}
  ```
  """

  @typedoc false
  @type from :: StateServer.from

  @typedoc false
  @type reply_response :: StateServer.reply_response

  @typedoc false
  @type noreply_response :: StateServer.noreply_response

  @typedoc false
  @type stop_response :: StateServer.stop_response

  @callback handle_call(term, from, term) :: reply_response | noreply_response | stop_response
  @callback handle_cast(term, term) :: noreply_response | stop_response
  @callback handle_continue(term, term) :: noreply_response | stop_response
  @callback handle_info(term, term) :: noreply_response | stop_response
  @callback handle_internal(term, term) :: noreply_response | stop_response
  @callback handle_timeout(term, term) :: noreply_response | stop_response
  @callback handle_transition(atom, term) :: noreply_response | stop_response | :cancel
  @callback on_state_entry(atom, term) :: StateServer.on_state_entry_response

  @optional_callbacks [handle_call: 3, handle_cast: 2, handle_continue: 2,
    handle_info: 2, handle_internal: 2, handle_timeout: 2, handle_transition: 2,
    on_state_entry: 2]

end
