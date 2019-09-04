defmodule StateServer do

  @switch_doc File.read!("test/examples/switch.exs")

  # TODO: implement default callbacks.

  @moduledoc """
  A wrapper for `:gen_statem` which preserves `GenServer`-like semantics.

  ## Motivation

  The `:gen_statem` event callback is complex, with a confusing set of response
  definitions, the documentation isn't that great, the states of the state
  machine are a bit too loosey-goosey and not explicitly declared anywhere in a
  single referential place in the code; you have to read the result bodies of
  several function bodies to understand the state graph.

  `StateServer` changes that.  There are three major objectives:
  -  Fanout the callback handling
  -  Unify callback return type with that of `GenServer`, and sanitize
  -  Enforce the use of a programmer-defined state graph.

  ## Defining the state graph

  The state graph is defined at **compile time** by setting the `state_graph` keyword
  in the `use` statement.  This `state_graph` is a keyword list of keyword lists.
  The outer keyword list has the state names (atoms) as keys and the inner keyword
  lists have transitions (atoms) as keys, and destination states as values.  The
  first keyword in the state graph is the initial state of the state machine.
  **Defining the state graph is required**.

  At compile time, `StateServer` will verify that all of the state graph's
  transition destinations exist as declared states; you may need to explicitly
  declare that a particular state is terminal by having it key into the empty
  list `[]`.

  ### Example

  the state graph for a light switch might look like this:

  ```elixir
  use StateServer, state_graph: [on: [flip: :off],
                                 off: [flip: :on]]
  ```

  #### 'Magic' things

  The following guards will be defined for you automatically.
  - `c:is_terminal/1`: true *iff* the argument is a terminal state.
  - `c:is_terminal_transition/2`: true *iff* starting from `&1` through transition `&2` leads to a
    terminal state.
  - `c:is_edge/3`: true *iff* starting from `&1` through transition `&2` leads to `&3`

  The following types are defined for you automatically.
  - `state` which is a union type of all state atoms.
  - `transition` which is a union type of all transition atoms.

  ## State machine data

  A `StateServer`, like all `:gen_statem`s carry additional data of any term
  in addition to the state, to ensure that they can perform all Turing-computable
  operations.  You are free to make the data parameter whatever you would like.
  It is encouraged to declare the `data` type in the module which defines the
  typespec of this state machine data.

  ## Callbacks

  The following callbacks are all optional and are how you implement
  functionality for your StateServer.

  ### External callbacks:

  - `c:handle_call/4` responds to a message sent via `GenServer.call/3`.
    Like `c:GenServer.handle_call/3`, the calling process will block until you
    a reply, using either the `{:reply, reply}` tuple, or, if you emit `:noreply`,
    a subsequent call to `reply/2` in a continuation.  Note that if you do not
    reply within the call's expected timeout, the calling process will crash.

  - `c:handle_cast/3` responds to a message sent via `GenServer.cast/2`.
    Like `c:GenServer.handl_cast/2`, the calling process will immediately return
    and this is effectively a `fire and forget` operation with no backpressure
    response.

  - `c:handle_info/3` responds to a message sent via `send/2`.  Typically this
    should be used to trap system messages that result from a message source
    that has registered the active StateServer process as a message sink, such
    as network packets or `:nodeup`/`:nodedown` messages (among others).

  ### Internal callbacks

  - `c:handle_internal/3` responds to internal *events* which have been sent
    forward in time using the `{:internal, payload}` setting.  This is
    `:gen_statem`'s primary method of doing continuations.  If you have code
    that you think will need to be compared against or migrate to a
    `:gen_statem`, you should use this semantic.

  - `c:handle_continue/3` responds to internal *events* which have been sent
    forward in time using the `{:continue, payload}` setting.  This is `GenServer`'s
    primary method of performing continuations.  If you have code that you
    think will need to be compared against or migrate to a `GenServer`, you should
    use this form.  A typical use of this callback is to handle a long-running
    task that needs to be triggered after initialization.  Because `start_link/2`
    will timeout, `StateMachine` initialization

  - `c:handle_timeout/3` handles all timeout events.  See the [timeout section](#module-timeouts)
    for more information

  - `c:handle_transition/3` is triggered whenever you change states using the
    `{:transition, transition}` event.  Note that it's **not** triggered by a
    `{:goto, state}` event.  You may find the `c:is_edge/3` callback guard to
    be useful for discriminating which transitions you care about.

  ## Callback responses

  - `c:handle_call/4` typically issues a **reply** response.  A reply response takes the
      one of two forms, `{:reply, reply}` or `{:reply, reply, event_list}`  It may also
      take the **noreply** form, with a deferred reply at some other time.
  - all of the callback responses may issue a **noreply** response, which takes one of
      two forms, `:noreply` or `{:noreply, event_list}`

  ### The event list

  The event list consists of one of several forms:
  ```elixir
  {:transition, transition}            # sends the state machine through the transition
  {:update, new_data}                  # updates the data portion of the state machine

  {:goto, new_state}                   # changes the state machine state without a transition
  {:internal, payload}                 # sends an internal event
  {:continue, payload}                 # sends a continuation

  {:event_timeout, {payload, time}}    # sends an event timeout with a payload
  {:event_timeout, time}               # sends an event timeout without a payload
  {:state_timeout, {payload, time}}    # sends a state timeout with a payload
  {:state_timeout, time}               # sends a state timeout without a payload
  {:timeout, {payload, time}}          # sends a plain timeout with a payload
  {:timeout, time}                     # sends a plain timeout without a payload
  :noop                                # does nothing
  ```

  **transition** and **update** events are special.  If they are at the head of the event
  list, (and in that order) they will be handled atomically in the current function call;
  if they are not at the head of the event list, separate internal events will be
  generated, and they will be executed as separate calls in their event order.

  Typically, these should be represented in the event response as part of an Elixir
  keyword list, for example:

  ```elixir
  {:noreply, transition: :flip, internal: {:add, 3}, state_timeout: 250}
  ```

  You may also generally provide events as tuples that are expected by
  `:gen_statem`, for example: `{:next_event, :internal, {:foo, "bar"}}`, but
  note that if you do so Elixir's keyword sugar will not be supported.

  ### Transition vs. goto

  **Transitions** represent the main business logic of your state machine.  They come
  with an optional transition handler, so that you can write code that will be ensured
  to run on all state transitions with the same name, instead of requiring these to be
  in the code body of your event.  You **should** be using transitions everywhere.

  However, there are some cases when you will want to skip straight to a state without
  traversing the state graph.  Here are some cases where you will want to do that:

  - If you want to start at a state *other than* the head state, depending on environment
    at the start
  - If you want to do a unit test and skip straight to some state that you're testing.
  - If your gen_statem has crashed, and you need to restart it in a state that isn't the
    default initial state.

  ## Timeouts

  `StateServer` state machines respect three types of timeouts:

  - `:event_timeout`.  These are cancelled when any *internal* OR *external*
    event hits the genserver.  Typically, an event_timeout definition should
    be the last term in the event list, otherwise the succeeding internal
    event will cancel the timeout.
  - `:state_timeout`.  These are cancelled when the state of the state machine
    changes.
  - `:timeout`.  These are not cancelled, unless you reset their value to
    `:infinity`.

  In general, if you need to name your timeouts, you should include the "name"
  of the timeout in the "payload" section, as the first element in a tuple;
  you will then be able to pattern match this in your `c:handle_timeout/3`
  headers.  If you do not include a payload, then they will be explicitly sent
  a `nil` value.

  ## Example:

  ```elixir
  #{@switch_doc}
  ```

  """

  @behaviour :gen_statem

  alias StateServer.InvalidStateError
  alias StateServer.InvalidTransitionError
  alias StateServer.StateGraph

  @typedoc """
  events which can be put on the state machine's event queue.

  these are largely the same as `t::gen_statem.event_type/0` but have been
  reformatted to be more user-friendly.
  """
  @type event ::
    {:internal, term} | {:continue, term} |
    {:event_timeout, {term, non_neg_integer}} | {:event_timeout, non_neg_integer} |
    {:state_timeout, {term, non_neg_integer}} | {:state_timeout, non_neg_integer} |
    {:timeout, non_neg_integer} | {:timeout, {term, non_neg_integer}} |
    {:transition, atom} | {:update, term} | {:goto, atom} | :noop | :gen_statem.event_type

  @typedoc false
  @type from :: {pid, tag :: term}

  @typedoc "handler output when there's a response"
  @type reply_response :: {:reply, term, [event]}

  @typedoc "handler output when there isn't a response"
  @type noreply_response :: {:noreply, [event]}

  @typedoc "handler output when the state machine should stop altogether"
  @type stop_response ::
    :stop | {:stop, reason :: term} | {:stop, reason :: term, new_data :: term} |
    {:stop_and_reply, reason :: term, replies :: [:gen_statem.reply_action] | :gen_statem.reply_action} |
    {:stop_and_reply, reason :: term, replies :: [:gen_statem.reply_action] | :gen_statem.reply_action, new_data :: term}

  @doc """
  starts the state machine, similar to `c:GenServer.init/1`

  **NB** the expected response of `c:init/1` is `{:ok, data}` which does not
  include the initial state.  The initial state is set as the first key in the
  `:state_graph` parameter of the `use StateServer` directive.  If you must
  initialize the state to something else, use the `{:ok, data, goto: state}`
  response.

  You may also respond with the usual `GenServer.init/1` responses, such as:

  - `:ignore`
  - `{:stop, reason}`
  """
  @callback init(any) :: :gen_statem.init_result(atom)

  @doc """
  handles messages sent to the StateMachine using `StateServer.call/3`
  """
  @callback handle_call(term, from, state :: atom, data :: term) ::
    reply_response | noreply_response | stop_response

  @doc """
  handles messages sent to the StateMachine using `StateServer.cast/2`
  """
  @callback handle_cast(term, state :: atom, data :: term) ::
    noreply_response | stop_response

  @doc """
  handles messages sent by `send/2` or other system message generators.
  """
  @callback handle_info(term, state :: atom, data :: term) ::
    noreply_response | stop_response

  @doc """
  handles events sent by the `{:internal, payload}` event response.
  """
  @callback handle_internal(term, state :: atom, data :: term) ::
    noreply_response | stop_response

  @doc """
  handles events sent by the `{:continue, payload}` event response.

  **NB** a continuation is simply an `:internal` event with a reserved word
  tag attached.
  """
  @callback handle_continue(term, state :: atom, data :: term) ::
    noreply_response | stop_response

  @doc """
  triggered when a set timeout event has timed out.  See [timeouts](#module-timeouts)
  """
  @callback handle_timeout(payload::term, state :: atom, data :: term) ::
    noreply_response | stop_response

  @doc """
  triggered when a state change has been initiated via a `{:transition, transition}`
  event.

  NB: you may want to use the `c:is_terminal_transition/2` or the `c:is_edge/3`
  callback defguards here.
  """
  @callback handle_transition(state :: atom, transition :: atom, data :: term) ::
    noreply_response | stop_response

  @optional_callbacks [handle_call: 4, handle_cast: 3, handle_info: 3,
    handle_internal: 3, handle_continue: 3, handle_timeout: 3, handle_transition: 3]

  @doc """
  an autogenerated guard which can be used to check if a state is terminal
  """
  @macrocallback is_terminal(state::atom) :: Macro.t

  @doc """
  an autogenerated guard which can be used to check if a state and transition
  will lead to a terminal state.
  """
  @macrocallback is_terminal_transition(state::atom, transition::atom) :: Macro.t

  @doc """
  an autogenerated guard which can be used to check if a state and transition
  will lead to any state.
  """
  @macrocallback is_edge(state::atom, transition::atom, dest::atom) :: Macro.t

  defmacro __using__(opts) do

    unless Keyword.has_key?(opts, :state_graph) do
      raise ArgumentError, "StateServer must have a state_graph parameter."
    end

    state_graph = opts[:state_graph]

    unless StateGraph.valid?(state_graph) do
      env = __CALLER__
      raise %CompileError{file: env.file, line: env.line, description: "state_graph sent to StateServer is malformed"}
    end

    terminal_states = StateGraph.terminal_states(state_graph)
    terminal_transitions = StateGraph.terminal_transitions(state_graph)

    state_typelist = state_graph
    |> StateGraph.states
    |> StateGraph.atoms_to_typelist

    transition_typelist = state_graph
    |> StateGraph.transitions
    |> StateGraph.atoms_to_typelist

    edges = StateGraph.edges(state_graph)

    quote do
      import StateServer, only: [reply: 2]

      @behaviour StateServer

      @type state :: unquote(state_typelist)
      @type transition :: unquote(transition_typelist)

      @__modname__ __MODULE__ |> Module.split |> tl |> Enum.join(".")

      @doc """
      true *iff* going the specified state is terminal in `#{@__modname__}`
      """
      @impl true
      defguard is_terminal(state) when state in unquote(terminal_states)

      @doc """
      true *iff* going from state to transition leads to a terminal state
      for `#{@__modname__}`
      """
      @impl true
      defguard is_terminal_transition(state, transition)
        when {state, transition} in unquote(terminal_transitions)

      @doc """
      true *iff* (state -> transition -> destination) is a proper
      edge of the state graph for `#{@__modname__}`
      """
      @impl true
      defguard is_edge(state, transition, destination)
        when {state, {transition, destination}} in unquote(edges)

      @state_graph unquote(state_graph)

      @doc false
      @spec __state_graph__() :: StateServer.StateGraph.t
      def __state_graph__, do: @state_graph

      @doc false
      @spec __transition__(state, transition) :: state
      def __transition__(state, transition) do
        StateGraph.transition(@state_graph, state, transition)
      end
    end
  end

  @typedoc false
  @type server :: :gen_statem.server_ref

  @typedoc false
  @type start_option :: :gen_statem.options | {:name, atom}

  @spec start_link(module, term, [start_option]) :: :gen_statem.start_ret
  def start_link(module, initializer, options \\ []) do
    case Keyword.pop(options, :name) do
      {nil, options} ->
        :gen_statem.start_link(__MODULE__, {module, initializer}, options)

      {atom, options} when is_atom(atom) ->
        :gen_statem.start_link({:local, atom}, __MODULE__,
          {module, initializer}, Keyword.delete(options, :name))

      {global = {:global, _term}, options} ->
        :gen_statem.start_link(global, __MODULE__,
        {module, initializer}, Keyword.delete(options, :name))

      {via = {:via, via_module, _term}, options} when is_atom(via_module) ->
        :gen_statem.start_link(via, __MODULE__,
        {module, initializer}, Keyword.delete(options, :name))

      {other, _} ->
        raise ArgumentError, """
        expected :name option to be one of the following:
          * nil
          * atom
          * {:global, term}
          * {:via, module, term}
        Got: #{inspect(other)}
        """
    end
  end

  @typep init_result :: :gen_statem.init_result(atom)

  @impl true
  @spec init({module, term}) :: init_result
  def init({module, parameters}) do
    case (module.init(parameters)) do
      {:ok, data} ->
        {:ok,
          StateGraph.start(module.__state_graph__()),
          %{module: module, data: data}}
      {:ok, data, continue: continuation} ->
        {:ok,
          StateGraph.start(module.__state_graph__()),
          %{module: module, data: data},
          {:next_event, :internal, {:"$continue", continuation}}}
      {:ok, data, internal: payload} ->
        {:ok,
          StateGraph.start(module.__state_graph__()),
          %{module: module, data: data},
          {:next_event, :internal, payload}}
      {:ok, data, goto: state} ->
        {:ok, state, %{module: module, data: data}}
      {:ok, data, goto: state, continue: continuation} ->
        {:ok,
          state,
          %{module: module, data: data},
          {:next_event, :internal, {:"$continue", continuation}}}
      {:ok, data, goto: state, internal: payload} ->
        {:ok,
          state,
          %{module: module, data: data},
          {:next_event, :internal, payload}}
      any -> any
    end
  end

  @impl true
  @spec callback_mode() :: :handle_event_function
  def callback_mode, do: :handle_event_function

  @spec convert([event]) :: [:gen_statem.event_type]
  defp convert([]), do: []
  defp convert([{:internal, x} | rest]), do: [{:next_event, :internal, x} | convert(rest)]
  defp convert([{:continue, continuation} | rest]), do: [{:next_event, :internal, {:"$continue", continuation}} | convert(rest)]
  defp convert([{:event_timeout, {payload, time}} | rest]), do: [{:timeout, time, payload} | convert(rest)]
  defp convert([{:event_timeout, time} | rest]), do: [time | convert(rest)]
  defp convert([{:state_timeout, {payload, time}} | rest]), do: [{:state_timeout, time, payload} | convert(rest)]
  defp convert([{:state_timeout, time} | rest]), do: [{:state_timeout, time, time} | convert(rest)]
  defp convert([{:timeout, {payload, time}} | rest]), do: [{{:timeout, nil}, time, payload} | convert(rest)]
  defp convert([{:timeout, time} | rest]), do: [{{:timeout, nil}, time, nil} | convert(rest)]
  defp convert([{:transition, tr} | rest]), do: [{:next_event, :internal, {:"$transition", tr}} | convert(rest)]
  defp convert([{:update, data} | rest]), do: [{:next_event, :internal, {:"$update", data}} | convert(rest)]
  defp convert([{:goto, state} | rest]), do: [{:next_event, :internal, {:"$goto", state}} | convert(rest)]
  defp convert([:noop | rest]), do: convert(rest)
  defp convert([any | rest]), do: [any | convert(rest)]

  @typep internal_event_result :: :gen_statem.event_handler_result(atom)
  @typep internal_data :: %{data: any, module: module}

  defp do_transition(module, state, tr, data, actions) do

    next_state = module.__transition__(state, tr)

    unless next_state do
      raise InvalidTransitionError, "transtion #{tr} does not exist in #{module}"
    end

    if function_exported?(module, :handle_transition, 3) do
      case module.handle_transition(state, tr, data.data) do
        :noreply ->
          {:next_state, next_state, data, convert(actions)}

        {:noreply, extra_actions} ->
          {:next_state, next_state, data, convert(actions ++ extra_actions)}
      end
    else
      {:next_state, next_state, data, convert(actions)}
    end
  end

  defp translate_reply(msg, from, state, data = %{module: module}) do
    case msg do
      {:reply, reply} ->
        {:keep_state_and_data, [{:reply, from, reply}]}

      {:reply, reply, [{:transition, tr}, {:update, new_data} | actions]} ->
        do_transition(module, state, tr, %{data | data: new_data},
          [{:reply, from, reply} | actions])

      {:reply, reply, [{:transition, tr} | actions]} ->
        do_transition(module, state, tr, data, [{:reply, from, reply} | actions])

      {:reply, reply, [{:update, new_data} | actions]} ->
        {:keep_state, %{data | data: new_data},
          [{:reply, from, reply} | convert(actions)]}

      {:reply, reply, actions} ->
        {:keep_state_and_data,
          [{:reply, from, reply} | convert(actions)]}

      other_msg -> other_msg
    end
  end

  defp translate_noreply(msg, state, data = %{module: module}) do
    case msg do
      :noreply -> {:keep_state_and_data, []}

      {:noreply, [{:transition, tr}, {:update, new_data} | actions]} ->
        do_transition(module, state, tr, %{data | data: new_data}, actions)

      {:noreply, [{:transition, tr} | actions]} ->
        do_transition(module, state, tr, data, actions)

      {:noreply, [{:update, new_data} | actions]} ->
        {:keep_state, %{data | data: new_data}, convert(actions)}

      {:noreply, actions} ->
        {:keep_state_and_data, convert(actions)}

      other_msg -> other_msg
    end
  end

  @impl true
  @spec handle_event(event, any, atom, internal_data) :: internal_event_result
  def handle_event({:call, from}, content, state, data = %{module: module}) do
    content
    |> module.handle_call(from, state, data.data)
    |> translate_reply(from, state, data)
    |> translate_noreply(state, data)
  end
  def handle_event(:info, content, state, data = %{module: module}) do
    content
    |> module.handle_info(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event(:cast, content, state, data = %{module: module}) do
    content
    |> module.handle_cast(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event(:internal, {:"$transition", transition}, state, data = %{module: module}) do
    do_transition(module, state, transition, data, [])
  end
  def handle_event(:internal, {:"$goto", state}, _state, data = %{module: module}) do
    unless Keyword.has_key?(module.__state_graph__, state) do
      raise InvalidStateError, "#{state} not in states for #{module}"
    end
    {:next_state, state, data, []}
  end
  def handle_event(:internal, {:"$update", new_data}, _state, data) do
    {:keep_state, %{data | data: new_data}, []}
  end
  def handle_event(:internal, {:"$continue", continuation}, state, data = %{module: module}) do
    continuation
    |> module.handle_continue(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event(:internal, content, state, data = %{module: module}) do
    content
    |> module.handle_internal(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event(:timeout, time, state, data = %{module: module}) do
    time
    |> module.handle_timeout(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event(:state_timeout, payload, state, data = %{module: module}) do
    payload
    |> module.handle_timeout(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event({:timeout, nil}, payload, state, data = %{module: module}) do
    payload
    |> module.handle_timeout(state, data.data)
    |> translate_noreply(state, data)
  end
  def handle_event({:timeout, name}, payload, state, data = %{module: module}) do
    {name, payload}
    |> module.handle_timeout(state, data.data)
    |> translate_noreply(state, data)
  end

  #############################################################################
  ## GenServer wrappers.

  # these should all be inlined.
  @compile {:inline, call: 3, cast: 2, reply: 2, code_change: 4, format_status: 2}

  @spec call(server, any, timeout) :: term
  @doc "should be identical to `GenServer.call/3`"
  def call(server, request, timeout \\ 5000), do: :gen_statem.call(server, request, timeout)

  @spec cast(server, any) :: :ok
  @doc "should be identical to `GenServer.cast/2`"
  def cast(server, request), do: :gen_statem.cast(server, request)

  @spec reply(from, any) :: :ok
  @doc "should be identical to `GenServer.reply/2`"
  def reply(from, response), do: :gen_statem.reply(from, response)

  @impl true
  def code_change(vsn, state, data = %{module: module}, extra) do
    case module.code_change(vsn, state, data.data, extra) do
      {:ok, new_state, new_data} ->
        {:ok, new_state, %{data | data: new_data}}
      failure -> failure
    end
  end

  @impl true
  def format_status(status, [pdict, state, data = %{module: module}]) do
    if function_exported?(module, :format_status, 2) do
      module.format_status(status, [pdict, state, data.data])
    else
      format_status_default(status, data.data)
    end
  end

  defp format_status_default(:terminate, data), do: data.data
  defp format_status_default(_, data), do: [{:data, [{"State", data.data}]}]

end
