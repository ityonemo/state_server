defmodule StateServer.State do

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
