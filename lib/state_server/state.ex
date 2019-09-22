defmodule StateServer.State do

  @type reply_response :: StateServer.reply_response
  @type noreply_response :: StateServer.noreply_response
  @type stop_response :: StateServer.stop_response

  @callback handle_call(term, StateServer.from, term) :: reply_response | noreply_response | stop_response

  @optional_callbacks [handle_call: 3]

end
