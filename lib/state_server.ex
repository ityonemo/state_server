defmodule StateServer do

  @state_server_code File.read!("example/switch.exs")

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

  The state graph is defined at **compile time** using the keyword list in the
  `use` statement.  This `state_graph` is a keyword list of keyword lists. The
  outer keyword list has the state names (atoms) as keys and the inner keyword
  lists have transitions (atoms) as keys, and destination states as values.
  The first keyword in the state graph is the initial state of the state
  machine. **Defining the state graph is required**.

  At compile time, `StateServer` will verify that all of the state graph's
  transition destinations exist as declared states; you may need to explicitly
  declare that a particular state is terminal by having it key into the empty
  list `[]`.

  ### Example

  the state graph for a light switch might look like this:

  ```elixir
  use StateServer, on: [flip: :off],
                   off: [flip: :on]
  ```

  #### 'Magic' things

  The following guards will be defined for you automatically.
  - `c:is_terminal/1`: true *iff* the argument is a terminal state.
  - `c:is_terminal/2`: true *iff* starting from `&1` through transition `&2` leads to a
    terminal state.
  - `c:is_transition/2`: true *iff* `&2` is a proper transition of `&1`
  - `c:is_transition/3`: true *iff* starting from `&1` through transition `&2` leads to `&3`

  The following types are defined for you automatically.
  - `state` which is a union type of all state atoms.
  - `transition` which is a union type of all transition atoms.

  The following module attributes are available at compile-time:
  - `@state_graph` is the state graph as passed in the `use` statement
  - `@initial_state` is the initial state of the state graph.  Note that
    there are cases when the StateServer itself should not start in that
    state, for example if it is being restarted by an OTP supervisor and
    should search for its state from some other source of ground truth.

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
    will timeout, if `StateMachine`, then you should these tasks using the continue
    callback.

  - `c:handle_timeout/3` handles all timeout events.  See the [timeout section](#module-timeouts)
    for more information

  - `c:handle_transition/3` is triggered whenever you change states using the
    `{:transition, transition}` event.  Note that it's **not** triggered by a
    `{:goto, state}` event.  You may find the `c:is_edge/3` callback guard to
    be useful for discriminating which transitions you care about.

  ### Special callbacks

  - `c:on_state_entry/3` will be triggered for the starting state (whether as a default or
    as set by a `goto:` parameter in `c:init/1`), and when any event causes the state machine
    to change state or repeat state

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
  {:timeout, {name, payload, time}}    # sends a plain timeout with a name, and a payload
  {:timeout, {name, time}}             # sends a plain timeout with a name, but no payload
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
    changes.  **NB** a state machine may only have one state timeout active
    at any given time.
  - `:timeout`.  These are not cancelled, unless you reset their value to
    `:infinity`.

  In general, if you need to name your timeouts, you should include the "name"
  of the timeout in the "payload" section, as the first element in a tuple;
  you will then be able to pattern match this in your `c:handle_timeout/3`
  headers.  If you do not include a payload, then they will be explicitly sent
  a `nil` value.

  ## Organizing your code

  If you would like to organize your implementations by state, consider using
  the `StateServer.State` behaviour pattern.

  ## Example basic implementation:

  ```elixir
  #{@state_server_code}
  ```
  """

  @behaviour :gen_statem

  require StateServer.Macros

  alias StateServer.InvalidStateError
  alias StateServer.InvalidTransitionError
  alias StateServer.Macros
  alias StateServer.StateGraph

  @typedoc """
  events which can be put on the state machine's event queue.

  these are largely the same as `t::gen_statem.event_type/0` but have been
  reformatted to be more user-friendly.
  """
  @type event ::
    {:transition, atom} | {:goto, atom} | {:update, term} | {:internal, term} | {:continue, term} |
    {:event_timeout, {term, non_neg_integer}} | {:event_timeout, non_neg_integer} |
    {:state_timeout, {term, non_neg_integer}} | {:state_timeout, non_neg_integer} |
    {:timeout, {term, non_neg_integer}} | {:timeout, non_neg_integer} |
    :noop | :gen_statem.event_type

  @typedoc false
  @type from :: {pid, tag :: term}

  @typedoc "handler output when there's a response"
  @type reply_response :: {:reply, term, [event]} | {:reply, term}

  @typedoc "handler output when there isn't a response"
  @type noreply_response :: {:noreply, [event]} | :noreply

  @typedoc "handler output when you want to defer to a state module"
  @type defer_response :: {:defer, [event]} | :defer

  @typedoc "handler output when the state machine should stop altogether"
  @type stop_response ::
    :stop | {:stop, reason :: term} | {:stop, reason :: term, new_data :: term} |
    {:stop_and_reply,
      reason :: term,
      replies :: [:gen_statem.reply_action] | :gen_statem.reply_action} |
    {:stop_and_reply,
      reason :: term,
      replies :: [:gen_statem.reply_action] | :gen_statem.reply_action,
      new_data :: term}

  @type timeout_payload :: {name :: atom, payload :: term} | (name :: atom) | (payload :: term)

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

  You can also initialize and instrument one of several keyword parameters.
  For example, you may issue `{:internal, term}` or `{:continue, term}` to
  send an internal message as part of a startup continuation.  You may
  send `{:timeout, {term, timeout}}` to send a delayed continuation; this
  is particularly useful to kick off a message loop.

  Any of these keywords may be preceded by `{:goto, state}` which will
  set the initial state, which is useful for resurrecting a supervised
  state machine into a state without a transition.

  ### Example

  ```elixir
  def init(log) do
    # uses both the goto and the timeout directives to either initialize
    # a fresh state machine or resurrect from a log.  In both cases,
    # sets up a ping loop to perform some task.
    case retrieve_log(log) do
      nil ->
        {:ok, default_value, timeout: {:ping, 50}}
      {previous_state, value} ->
        {:ok, value, goto: previous_state, timeout: {:ping, 50}}
    end
  end

  # for reference, what that ping loop might look like.
  def handle_timeout(:ping, _state, _data) do
    do_ping(:ping)
    {:noreply, timeout: {:ping, 50}}
  end
  ```
  """
  @callback init(any) ::
    {:ok, initial_data::term} |
    {:ok, initial_data::term, internal: term} |
    {:ok, initial_data::term, continue: term} |
    {:ok, initial_data::term, timeout: {term, timeout}} |
    {:ok, initial_data::term, goto: atom} |
    {:ok, initial_data::term, goto: atom, internal: term} |
    {:ok, initial_data::term, goto: atom, continue: term} |
    {:ok, initial_data::term, goto: atom, timeout: {term, timeout}} |
    {:ok, initial_data::term, goto: atom, timeout: timeout} |
    {:ok, initial_data::term, goto: atom, state_timeout: {term, timeout}} |
    {:ok, initial_data::term, goto: atom, state_timeout: timeout} |
    {:ok, initial_data::term, goto: atom, event_timeout: {term, timeout}} |
    {:ok, initial_data::term, goto: atom, event_timeout: timeout} |
    :ignore | {:stop, reason :: any}

  @doc """
  handles messages sent to the StateMachine using `StateServer.call/3`
  """
  @callback handle_call(term, from, state :: atom, data :: term) ::
    reply_response | noreply_response | stop_response | defer_response

  @doc """
  handles messages sent to the StateMachine using `StateServer.cast/2`
  """
  @callback handle_cast(term, state :: atom, data :: term) ::
    noreply_response | stop_response | defer_response

  @doc """
  handles messages sent by `send/2` or other system message generators.
  """
  @callback handle_info(term, state :: atom, data :: term) ::
    noreply_response | stop_response | defer_response

  @doc """
  handles events sent by the `{:internal, payload}` event response.
  """
  @callback handle_internal(term, state :: atom, data :: term) ::
    noreply_response | stop_response | defer_response

  @doc """
  handles events sent by the `{:continue, payload}` event response.

  **NB** a continuation is simply an `:internal` event with a reserved word
  tag attached.
  """
  @callback handle_continue(term, state :: atom, data :: term) ::
    noreply_response | stop_response | defer_response

  @doc """
  triggered when a set timeout event has timed out.  See [timeouts](#module-timeouts)
  """
  @callback handle_timeout(payload::timeout_payload, state :: atom, data :: term) ::
    noreply_response | stop_response | defer_response

  @doc """
  triggered when a state change has been initiated via a `{:transition, transition}`
  event.

  should emit `:noreply`, or `{:noreply, extra_actions}` to handle the normal case
  when the transition should proceed.  If the transition should be cancelled,
  emit `:cancel` or `{:cancel, extra_actions}`.

  NB: you may want to use the `c:is_terminal/2` or the `c:is_transition/3`
  callback defguards here.
  """
  @callback handle_transition(state :: atom, transition :: atom, data :: term) ::
    noreply_response | stop_response | defer_response | :cancel

  @doc """
  triggered when the process is about to be terminated.  See:
  `c::gen_statem.terminate/3`
  """
  @callback terminate(reason :: term, state :: atom, data :: term) :: any

  @typedoc """
  on_state_entry function outputs

  only a subset of the available handler responses should be queued from
  a triggered `on_state_entry/3` event.
  """
  @type on_state_entry_event ::
    {:update, term} | {:internal, term} | {:continue, term} |
    {:event_timeout, {term, non_neg_integer}} | {:event_timeout, non_neg_integer} |
    {:state_timeout, {term, non_neg_integer}} | {:state_timeout, non_neg_integer} |
    {:timeout, {term, non_neg_integer}} | {:timeout, non_neg_integer}

  @typedoc false
  @type on_state_entry_response ::
    :noreply | {:noreply, [on_state_entry_event]}

  @doc """
  triggered on initialization or just prior to entering a state.

  If entering a state is done with a `:goto` statement or a `:gen_statem`
  state change, `transition` will be `nil`.

  Note that at this point the state change should not be cancelled.  If you
  need to cancel a transition, use `c:handle_transition/3` with the `:cancel`
  return value.

  response should be :noreply or a :noreply tuple with a  restricted set of
  events which can be enqueued onto the events list:

  - `:update`
  - `:internal`
  - `:continue`
  - `:event_timeout`
  - `:state_timeout`
  - `:timeout`

  Like the other callbacks, you may call :defer here to defer to the state machines.
  """
  @callback on_state_entry(transition :: atom, state :: atom, data :: term) ::
    on_state_entry_response | :defer

  @doc """
  an autogenerated guard which can be used to check if a state is terminal
  """
  @macrocallback is_terminal(state::atom) :: Macro.t

  @doc """
  an autogenerated guard which can be used to check if a state and transition
  will lead to a terminal state.
  """
  @macrocallback is_terminal(state::atom, transition::atom) :: Macro.t

  @doc """
  an autogenerated guard which can be used to check if a transition is valid for
  a state
  """
  @macrocallback is_transition(state::atom, transition::atom) :: Macro.t

  @doc """
  an autogenerated guard which can be used to check if a state and transition
  will lead to any state.
  """
  @macrocallback is_transition(state::atom, transition::atom, dest::atom) :: Macro.t

  @optional_callbacks [handle_call: 4, handle_cast: 3, handle_info: 3,
    handle_internal: 3, handle_continue: 3, handle_timeout: 3, handle_transition: 3,
    on_state_entry: 3, terminate: 3]

  @macro_callbacks [:is_terminal, :is_transition]

  @typep callbacks :: :handle_call | :handle_cast | :handle_info | :handle_internal |
    :handle_continue | :handle_timeout | :handle_transition

  # internal data type
  @typep data :: %{
    required(:module) => module,
    required(:data) => term,
    required(callbacks) => function
  }

  defmacro __using__(state_graph) do
    env = __CALLER__

    # we will want the module name for some documentation
    module_name = (env.module |> Module.split |> tl |> Enum.join("."))

    ([] == state_graph) && raise ArgumentError, "StateServer must have a state_graph parameter."

    # pull the state_graph and validate it.
    unless StateGraph.valid?(state_graph) do
      raise %CompileError{file: env.file, line: env.line, description: "state_graph sent to StateServer is malformed"}
    end

    # populate values that will be used in the autogenerated guards
    terminal_states = StateGraph.terminal_states(state_graph)
    terminal_transitions = StateGraph.terminal_transitions(state_graph)
    all_transitions = StateGraph.all_transitions(state_graph)
    edges = StateGraph.edges(state_graph)

    # generate value for our @initial_state attribute
    initial_state = StateGraph.start(state_graph)

    # create AST for autogenerated @type statements
    state_typelist = state_graph
    |> StateGraph.states
    |> StateGraph.atoms_to_typelist

    transition_typelist = state_graph
    |> StateGraph.transitions
    |> StateGraph.atoms_to_typelist

    quote do
      import StateServer, only: [reply: 2, defstate: 3, defstate: 2, defer: 1]

      @behaviour StateServer

      @type state :: unquote(state_typelist)
      @type transition :: unquote(transition_typelist)

      @doc """
      true *iff* going the specified state is terminal in `#{unquote(module_name)}`
      """
      @impl true
      defguard is_terminal(state) when state in unquote(terminal_states)

      @doc """
      true *iff* going from state to transition leads to a terminal state
      for `#{unquote(module_name)}`
      """
      @impl true
      defguard is_terminal(state, transition)
        when {state, transition} in unquote(terminal_transitions)

      @doc """
      true *iff* transition is a valid transition for the given state in
      `#{unquote(module_name)}`
      """
      @impl true
      defguard is_transition(state, transition)
        when {state, transition} in unquote(all_transitions)

      @doc """
      true *iff* (state -> transition -> destination) is a proper
      edge of the state graph for `#{unquote(module_name)}`
      """
      @impl true
      defguard is_transition(state, transition, destination)
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

      # provides a way for you to make your own overrideable
      # child_specs.
      @doc false
      def child_spec(init_arg, overrides) do
        Supervisor.child_spec(%{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }, overrides)
      end

      # provide an overridable default child_spec implementation.
      @doc false
      def child_spec(init_arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }
      end
      defoverridable child_spec: 1

      # keep track of state_modules
      Module.register_attribute(__MODULE__, :state_modules, accumulate: true, persist: true)

      @before_compile StateServer

      # make initial state value
      @initial_state unquote(initial_state)
    end
  end

  @typedoc false
  @type server :: :gen_statem.server_ref

  @typedoc false
  @type start_option :: :gen_statem.options | {:name, atom}

  # generalized starting process, that works for both start/2,3 and start_link/2,3
  defmacrop starter(start_fn) do
    states_mod = __MODULE__
    quote do
      # de-hygeinize parameters from the function
      {module, initializer, options} = {var!(module), var!(initializer), var!(options)}
      # populate a struct that generates lambdas for each of the overridden
      # callbacks.

      state = %{generate_selector(module) | data: initializer}

      case Keyword.pop(options, :name) do
        {nil, options} ->
          :gen_statem.unquote(start_fn)(unquote(states_mod), state, options)

        {atom, options} when is_atom(atom) ->
          :gen_statem.unquote(start_fn)({:local, atom}, unquote(states_mod),
            state, Keyword.delete(options, :name))

        {global = {:global, _term}, options} ->
          :gen_statem.unquote(start_fn)(global, unquote(states_mod),
          state, Keyword.delete(options, :name))

        {via = {:via, via_module, _term}, options} when is_atom(via_module) ->
          :gen_statem.unquote(start_fn)(via, unquote(states_mod),
          state, Keyword.delete(options, :name))

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
  end


  @spec start(module, term, [start_option]) :: :gen_statem.start_ret
  def start(module, initializer, options \\ []) do
    starter(:start)
  end

  @spec start_link(module, term, [start_option]) :: :gen_statem.start_ret
  def start_link(module, initializer, options \\ []) do
    starter(:start_link)
  end

  @typep init_result :: :gen_statem.init_result(atom)

  @impl true
  @spec init(data) :: init_result
  def init(init_data = %{module: module}) do
    default_state = StateGraph.start(module.__state_graph__())

    module.init(init_data.data)
    |> parse_init(default_state, init_data)
    |> do_on_entry_init
  end

  defp parse_init({:ok, data}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data}}
  end
  defp parse_init({:ok, data, continue: payload}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:next_event, :internal, {:"$continue", payload}}}
  end
  defp parse_init({:ok, data, internal: payload}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:next_event, :internal, payload}}
  end
  defp parse_init({:ok, data, timeout: {name, payload, time}}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {{:timeout, name}, time, payload}}
  end
  defp parse_init({:ok, data, timeout: {payload, time}}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {{:timeout, nil}, time, payload}}
  end
  defp parse_init({:ok, data, timeout: time}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {{:timeout, nil}, time, nil}}
  end
  defp parse_init({:ok, data, event_timeout: {payload, time}}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:timeout, time, {:"$event_timeout", payload}}}
  end
  defp parse_init({:ok, data, event_timeout: time}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:timeout, time, nil}}
  end
  defp parse_init({:ok, data, state_timeout: {payload, time}}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:state_timeout, time, payload}}
  end
  defp parse_init({:ok, data, state_timeout: time}, state, data_wrap) do
    {:ok, state, %{data_wrap | data: data},
      {:state_timeout, time, nil}}
  end
  defp parse_init({:ok, data, goto: state}, _, data_wrap) do
    parse_init({:ok, data}, state, data_wrap)
  end
  defp parse_init({:ok, data, [goto: state] ++ rest}, _, data_wrap) do
    parse_init({:ok, data, rest}, state, data_wrap)
  end
  defp parse_init(any, _, _), do: any

  @impl true
  @spec callback_mode() :: :handle_event_function
  def callback_mode, do: :handle_event_function

  @spec do_event_conversion([event]) :: [:gen_statem.event_type]
  defp do_event_conversion([]), do: []
  defp do_event_conversion([{:internal, x} | rest]), do: [{:next_event, :internal, x} | do_event_conversion(rest)]
  defp do_event_conversion([{:continue, continuation} | rest]), do: [{:next_event, :internal, {:"$continue", continuation}} | do_event_conversion(rest)]
  defp do_event_conversion([{:event_timeout, {payload, time}} | rest]), do: [{:timeout, time, {:"$event_timeout", payload}} | do_event_conversion(rest)]
  defp do_event_conversion([{:event_timeout, time} | rest]), do: [{:timeout, time, nil} | do_event_conversion(rest)]
  defp do_event_conversion([{:state_timeout, {payload, time}} | rest]), do: [{:state_timeout, time, payload} | do_event_conversion(rest)]
  defp do_event_conversion([{:state_timeout, time} | rest]), do: [{:state_timeout, time, nil} | do_event_conversion(rest)]
  defp do_event_conversion([{:timeout, {name, payload, time}} | rest]), do: [{{:timeout, name}, time, payload} | do_event_conversion(rest)]
  defp do_event_conversion([{:timeout, {name, time}} | rest]), do: [{{:timeout, name}, time, nil} | do_event_conversion(rest)]
  defp do_event_conversion([{:timeout, time} | rest]), do: [{{:timeout, nil}, time, nil} | do_event_conversion(rest)]
  defp do_event_conversion([{:transition, tr} | rest]), do: [{:next_event, :internal, {:"$transition", tr}} | do_event_conversion(rest)]
  defp do_event_conversion([{:update, data} | rest]), do: [{:next_event, :internal, {:"$update", data}} | do_event_conversion(rest)]
  defp do_event_conversion([{:goto, state} | rest]), do: [{:next_event, :internal, {:"$goto", state}} | do_event_conversion(rest)]
  defp do_event_conversion([:noop | rest]), do: do_event_conversion(rest)
  defp do_event_conversion([any | rest]), do: [any | do_event_conversion(rest)]

  @typep internal_event_result :: :gen_statem.event_handler_result(atom)
  @typep internal_data :: %{data: any, module: module}

  import StateServer.Macros, only: [do_defer_translation: 5, do_defer_translation: 6]

  defp do_transition(state, tr, data = %{module: module}, actions) do

    next_state = module.__transition__(state, tr)

    unless next_state do
      raise InvalidTransitionError, "transition #{tr} does not exist in #{module}"
    end

    state
    |> data.handle_transition.(tr, data.data)
    |> do_defer_translation(:handle_transition, state, tr, data)
    |> case do
      :cancel ->
        {:keep_state, data, do_event_conversion(actions)}

      {:cancel, extra_actions} ->
        {:keep_state, data, do_event_conversion(actions ++ extra_actions)}

      :noreply ->
        do_on_entry({:next_state, next_state, data, do_event_conversion(actions)}, tr, state, data)

      {:noreply, extra_actions} ->
        do_on_entry({:next_state, next_state, data, do_event_conversion(actions ++ extra_actions)}, tr, state, data)
    end
  end

  defp do_on_entry({:next_state, state, new_data, actions1}, tr, _old_state, data) do
    tr
    |> data.on_state_entry.(state, new_data.data)
    |> do_defer_translation(:on_state_entry, tr, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions2]} ->
        {:next_state, state, %{data| data: newer_data}, actions1 ++ do_event_conversion(actions2)}
      {:noreply, actions2} ->
        {:next_state, state, new_data, actions1 ++ do_event_conversion(actions2)}
      :noreply ->
        {:next_state, state, new_data, actions1}
    end
  end
  defp do_on_entry({:next_state, state, new_data}, tr, _old_state, data) do
    tr
    |> data.on_state_entry.(state, new_data.data)
    |> do_defer_translation(:on_state_entry, tr, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions]} ->
        {:next_state, state, %{data | data: newer_data}, do_event_conversion(actions)}
      {:noreply, actions} ->
        {:next_state, state, new_data, do_event_conversion(actions)}
      :noreply ->
        {:next_state, state, new_data}
    end
  end
  defp do_on_entry({:repeat_state, new_data, actions1}, tr, state, data) do
    tr
    |> data.on_state_entry.(state, new_data.data)
    |> do_defer_translation(:on_state_entry, tr, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions2]} ->
        {:repeat_state, %{data| data: newer_data}, actions1 ++ do_event_conversion(actions2)}
      {:noreply, actions2} ->
        {:repeat_state, new_data, actions1 ++ do_event_conversion(actions2)}
      :noreply ->
        {:repeat_state, new_data, actions1}
    end
  end
  defp do_on_entry({:repeat_state, new_data}, tr, state, data) do
    tr
    |> data.on_state_entry.(state, new_data.data)
    |> do_defer_translation(:on_state_entry, tr, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions]} ->
        {:repeat_state, %{data| data: newer_data}, do_event_conversion(actions)}
      {:noreply, actions} ->
        {:repeat_state, new_data, do_event_conversion(actions)}
      :noreply ->
        {:repeat_state, new_data}
    end
  end
  defp do_on_entry(:repeat_state, tr, state, data) do
    tr
    |> data.on_state_entry.(state, data.data)
    |> do_defer_translation(:on_state_entry, tr, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions]} ->
        {:repeat_state, %{data| data: newer_data}, do_event_conversion(actions)}
      {:noreply, actions} ->
        {:repeat_state, data, do_event_conversion(actions)}
      :noreply ->
        {:repeat_state, data}
    end
  end
  defp do_on_entry(any, _, _, _), do: any

  defp do_on_entry_init({:ok, state, data}), do: do_on_entry_init({:ok, state, data, []})
  defp do_on_entry_init({:ok, state, data, old_actions}) when is_list(old_actions) do
    nil
    |> data.on_state_entry.(state, data.data)
    |> do_defer_translation(:on_state_entry, nil, state, data)
    |> case do
      {:noreply, [{:update, newer_data} | actions]} ->
        {:ok, state, %{data | data: newer_data}, old_actions ++ do_event_conversion(actions)}
      {:noreply, actions} ->
        {:ok, state, data, old_actions ++ do_event_conversion(actions)}
      :noreply -> {:ok, state, data, old_actions}
    end
  end
  defp do_on_entry_init({:ok, state, data, old_action}), do: do_on_entry_init({:ok, state, data, [old_action]})
  defp do_on_entry_init(any), do: any

  defp do_reply_translation(msg, from, state, data) do
    case msg do
      {:reply, reply} ->
        {:keep_state_and_data, [{:reply, from, reply}]}

      {:reply, reply, [{:transition, tr}, {:update, new_data} | actions]} ->
        do_transition(state, tr, %{data | data: new_data},
          [{:reply, from, reply} | actions])

      {:reply, reply, [{:transition, tr} | actions]} ->
        do_transition(state, tr, data, [{:reply, from, reply} | actions])

      {:reply, reply, [{:update, new_data} | actions]} ->
        {:keep_state, %{data | data: new_data},
          [{:reply, from, reply} | do_event_conversion(actions)]}

      {:reply, reply, actions} ->
        {:keep_state_and_data,
          [{:reply, from, reply} | do_event_conversion(actions)]}

      {:stop, reason} ->
        {:stop, reason, data}

      {:stop, reason, new_data} ->
        {:stop, reason, %{data | data: new_data}}

      {:stop, reason, reply, new_data} ->
        reply(from, reply)
        {:stop, reason, %{data | data: new_data}}

      other_msg ->
        do_on_entry(other_msg, nil, state, data)
    end
  end

  defp do_noreply_translation(msg, state, data) do
    case msg do
      :noreply -> {:keep_state_and_data, []}

      {:noreply, [{:transition, tr}, {:update, new_data} | actions]} ->
        do_transition(state, tr, %{data | data: new_data}, actions)

      {:noreply, [{:transition, tr} | actions]} ->
        do_transition(state, tr, data, actions)

      {:noreply, [{:update, new_data} | actions]} ->
        {:keep_state, %{data | data: new_data}, do_event_conversion(actions)}

      {:noreply, actions} ->
        {:keep_state_and_data, do_event_conversion(actions)}

      other_msg ->
        do_on_entry(other_msg, nil, state, data)
    end
  end

  @impl true
  @spec handle_event(event, any, atom, internal_data) :: internal_event_result
  def handle_event({:call, from}, :"$introspect", state, data) do
    # for debugging purposes.
    reply(from, Map.put(data, :state, state))
    :keep_state_and_data
  end
  def handle_event({:call, from}, content, state, data) do
    content
    |> data.handle_call.(from, state, data.data)
    |> do_defer_translation(:handle_call, content, from, state, data)
    |> do_reply_translation(from, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:info, content, state, data) do
    content
    |> data.handle_info.(state, data.data)
    |> do_defer_translation(:handle_info, content, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:cast, content, state, data) do
    content
    |> data.handle_cast.(state, data.data)
    |> do_defer_translation(:handle_cast, content, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:internal, {:"$transition", transition}, state, data) do
    do_transition(state, transition, data, [])
  end
  def handle_event(:internal, {:"$goto", state}, old_state, data = %{module: module}) do
    unless Keyword.has_key?(module.__state_graph__, state) do
      raise InvalidStateError, "#{state} not in states for #{module}"
    end
    do_on_entry({:next_state, state, data}, nil, old_state, data)
  end
  def handle_event(:internal, {:"$update", new_data}, _state, data) do
    {:keep_state, %{data | data: new_data}, []}
  end
  def handle_event(:internal, {:"$continue", continuation}, state, data) do
    continuation
    |> data.handle_continue.(state, data.data)
    |> do_defer_translation(:handle_continue, continuation, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:internal, content, state, data) do
    content
    |> data.handle_internal.(state, data.data)
    |> do_defer_translation(:handle_internal, content, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:timeout, time, state, data) when
      is_integer(time) or is_nil(time) do
    nil
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, nil, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:timeout, {:"$event_timeout", payload}, state, data) do
    payload
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, payload, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:timeout, payload, state, data) do
    payload
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, payload, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event(:state_timeout, payload, state, data) do
    payload
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, payload, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event({:timeout, nil}, payload, state, data) do
    payload
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, payload, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event({:timeout, name}, nil, state, data) do
    name
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, name, state, data)
    |> do_noreply_translation(state, data)
  end
  def handle_event({:timeout, name}, payload, state, data) do
    {name, payload}
    |> data.handle_timeout.(state, data.data)
    |> do_defer_translation(:handle_timeout, {name, payload}, state, data)
    |> do_noreply_translation(state, data)
  end

  @impl true
  @spec terminate(any, atom, data) :: any
  def terminate(reason, state, %{module: module, data: data}) do
    with s_modules when not is_nil(s_modules) <- module.__info__(:attributes)[:state_modules],
         submodule when not is_nil(submodule) <- s_modules[state],
         true <- function_exported?(submodule, :terminate, 2) do
      submodule.terminate(reason, data)
    else
      _ ->
        function_exported?(module, :terminate, 3) && module.terminate(reason, state, data)
    end
  end

  #############################################################################
  ## GenServer wrappers.

  # these should all be inlined.
  @compile {:inline, call: 3, cast: 2, reply: 2, code_change: 4, format_status: 2}

  @spec call(server, any, timeout) :: term
  @doc "
  should be identical to `GenServer.call/3`

  **NB**: this behavior is consistent with the GenServer call but NOT the
  `:gen_statem.call/3`, which spawns a proxy process.  StateServer
  chooses the GenServer call to maintain consistency across developer
  expectations.  If you need `:gen_statem`-like behavior, you can manually
  call `:gen_statem.call/3` passing the pid or reference and it should work
  as expected.
  "
  def call(server, request, timeout \\ 5000) do
    GenServer.call(server, request, timeout)
  end

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

  # checks if a module implements a certain functional callback,
  # if it does, then add the appropriate lambda into the map.
  # if it doesn't, but has a state shim, then use that.  Otherwise,
  # fall back on the default which appears in this module.
  @spec add_callback(map, module, {atom, non_neg_integer}) :: map
  defp add_callback(selector, module, {fun, arity}) do
    shim = Macros.state_shim_for(fun)
    target = cond do
      function_exported?(module, fun, arity) ->
        :erlang.make_fun(module, fun, arity)
      function_exported?(module, shim, arity) ->
        :erlang.make_fun(module, shim, arity)
      true ->
        :erlang.make_fun(__MODULE__, fun, arity)
    end
    Map.put(selector, fun, target)
  end

  # does a pass over all of the optional callbacks, loading those lambdas
  # into the module struct.  Also loads the module into the selector.
  # should only be run once, at init() time
  @spec generate_selector(module) :: data
  defp generate_selector(module) do
    @optional_callbacks
    |> Enum.flat_map(&(&1))  # note that optional callbacks is an accumulating attribute
    |> Enum.reject(fn {fun, _} -> (fun in [:terminate | @macro_callbacks]) end) #ignore is_ functions.
    |> Enum.reduce(%{module: module, data: nil}, &add_callback(&2, module, &1))
  end

  ######################################################################
  ## default implementation of behaviour functions

  StateServer.Macros.default_handler handle_call: 4
  StateServer.Macros.default_handler handle_cast: 3
  StateServer.Macros.default_handler handle_continue: 3
  StateServer.Macros.default_handler handle_internal: 3
  StateServer.Macros.default_handler handle_timeout: 3

  @doc false
  @spec handle_info(term, atom, term) :: :noreply
  def handle_info(msg, _state, _data) do
    proc =
      case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

    pattern = '~p ~p received unexpected message in handle_info/3: ~p~n'
    :error_logger.error_msg(pattern, [__MODULE__, proc, msg])

    :noreply
  end

  @doc false
  @spec handle_transition(atom, atom, term) :: :noreply
  def handle_transition(_state, _transition, _data), do: :noreply

  @doc false
  @spec on_state_entry(atom, atom, term) :: :noreply
  def on_state_entry(_state, _transition, _data), do: :noreply

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

  ###############################################################################
  ## State modules

  @doc """
  Defines a state module to organize your code internally.

  Keep in mind that the arities of all of the callbacks are less one since
  the associated state is bound in the parent module.

  Example:

  ```elixir
  defstate On, for: :on do
    @impl true
    def handle_call(_, _, _) do
      ...
    end
  end
  ```
  """
  defmacro defstate(module_ast = {:__aliases__, _, [module_alias]}, [for: state], code) do
    module_name = Module.concat(__CALLER__.module, module_alias)
    code! = inject_behaviour(code)
    quote do
      @state_modules {unquote(state), unquote(module_name)}
      defmodule unquote(module_ast), unquote(code!)
    end
  end

  @doc """
  Like `defstate/3` but lets you define your module externally.

  Example:

  ```elixir
  defstate Some.Other.Module, for: :on
  ```
  """
  defmacro defstate(module, [for: state]) do
    module_name = Macro.expand(module, __CALLER__)
    quote do
      require unquote(module_name)  # the module needs to be loaded to avoid strange compilation race conditions.
      @state_modules {unquote(state), unquote(module_name)}
    end
  end

  defp inject_behaviour([do: {:__block__, [], codelines}]) do
    [do: {:__block__, [], [quote do
      @behaviour StateServer.State
    end | codelines]
    }]
  end

  defmacro __before_compile__(_) do
    module = __CALLER__.module

    state_graph = Module.get_attribute(module, :state_graph)
    state_modules = Module.get_attribute(module, :state_modules)

    # verify that our body modules are okay.
    Enum.each(Keyword.keys(state_modules), fn state ->
      unless Keyword.has_key?(state_graph, state) do
        raise ArgumentError, "you attempted to bind a module to nonexistent state #{state}"
      end
    end)

    shims = @optional_callbacks
    |> Enum.flat_map(&(&1))
    |> Enum.reject(fn {fun, _} -> fun in @macro_callbacks end)
    |> Enum.map(&make_shim(&1, state_modules))

    quote do
      unquote_splicing(shims)
    end
  end

  defp make_shim({fun, arity}, state_modules) do
    shim_parts = Enum.map(state_modules, fn {state, module} ->
      if function_exported?(module, fun, arity - 1) do
        make_function_for(module, fun, state)
      end
    end)
    quote do
      unquote_splicing(shim_parts)
    end
  end

  # handle_call is exceptional since it is a /4 function
  defp make_function_for(module, :handle_call, state) do
    quote do
      @doc false
      def __handle_call_shim__(msg, from, unquote(state), data) do
        unquote(module).handle_call(msg, from, data)
      end
    end
  end
  # handle transition has an unusal parameter order.
  defp make_function_for(module, :handle_transition, state) do
    quote do
      @doc false

      def __handle_transition_shim__(unquote(state), transition, data) do
        unquote(module).handle_transition(transition, data)
      end
    end
  end
  # works for handle_cast/3, handle_info/3, handle_internal/3, handle_continue/3, handle_timeout/3,
  # on_state_entry/3, and terminate/3
  defp make_function_for(module, fun, state)
       when fun in [:handle_cast, :handle_info, :handle_internal,
                    :handle_continue, :handle_timeout, :on_state_entry, :terminate] do
    shim_fn_name = Macros.state_shim_for(fun)
    quote do
      @doc false
      def unquote(shim_fn_name)(msg, unquote(state), data) do
        unquote(module).unquote(fun)(msg, data)
      end
    end
  end

  @doc """
  a shortcut which lets you trap all other cases and send them to be
  handled by individual state modules.

  ```elixir
  defer handle_call
  ```

  is equivalent to

  ```elixir
  def handle_call(_, _, _, _), do: :defer
  ```
  """
  defmacro defer({:handle_call, _, _}) do
    quote do
      def handle_call(_, _, _, _), do: :defer
    end
  end
  defmacro defer({fun, _, _}) when fun in
      [:handle_cast, :handle_info, :handle_internal, :handle_continue,
       :handle_timeout, :handle_transition, :on_state_entry] do
    quote do
      def unquote(fun)(_, _, _), do: :defer
    end
  end

  # a debugging tool
  @doc false
  @spec __introspect__(GenServer.server) :: map
  def __introspect__(srv), do: call(srv, :"$introspect")

end
