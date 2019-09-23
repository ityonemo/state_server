defmodule StateServer.State do

  @state_server_with_states_code File.read!("priv/switch_with_states.exs")

  @moduledoc """
  A behaviour that lets you organize code for your StateServer states.

  ## Organization

  When you define your StateServer, the StateServer module gives you the
  opportunity to define **state modules**.  These are typically (but not
  necessarily) submodules scoped under the main StateServer module.  In
  this way, your code for handling events can be neatly organized by
  state.  In some (but not all) cases, this may be the most appropriate
  way to keep your state machine codebase sane.

  ## Example

  The following code should produce a "light switch" state server that
  announces when it's been flipped.

  ```elixir
  #{@state_server_with_states_code}
  ```
  """

  @type from :: StateServer.from
  @type reply_response :: StateServer.reply_response
  @type noreply_response :: StateServer.noreply_response
  @type stop_response :: StateServer.stop_response

  @callback handle_call(term, from, term) :: reply_response | noreply_response | stop_response
  @callback handle_cast(term, term) :: noreply_response | stop_response
  @callback handle_continue(term, term) :: noreply_response | stop_response
  @callback handle_info(term, term) :: noreply_response | stop_response
  @callback handle_internal(term, term) :: noreply_response | stop_response
  @callback handle_timeout(term, term) :: noreply_response | stop_response
  @callback handle_transition(atom, term) :: noreply_response | stop_response | :cancel

  @optional_callbacks [handle_call: 3, handle_cast: 2, handle_continue: 2,
    handle_info: 2, handle_internal: 2, handle_timeout: 2, handle_transition: 2]

end
