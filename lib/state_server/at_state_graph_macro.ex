defmodule StateServer.AtStateGraphMacro do

  #
  #  Elixir's compile timing choices are not necessarily smooth for implementing
  #  features which are dependent on the user's @state_graph.  In order to get
  #  these features, the builtin Kernel @ operator must be suppressed, and this
  #  module must be included.  This is taken care of in the "__using__" macro of
  #  StateServer.
  #
  #  then we have to manually craft special is_terminal/1 and is_terminal/2 macros.
  #  we also supply a couple of builtin types.
  #

  @moduledoc false

  alias StateServer.StateGraph

  #
  #  create an overloaded @ operator macro which selectively handles state_graph.
  #
  defmacro @expr
  defmacro @{:state_graph, meta, []} do
    # dispatch zero-argument stategraph calls as one would normally,
    # via direct call to Kernel.@
    kernel_at(:state_graph, meta, [])
  end
  defmacro @{:state_graph, _meta, args} do
    # trap the @state_graph <term> calls here.
    make_is_terminal(args, __CALLER__)
  end
  defmacro @{name, meta, args} do
    # dispatch @ attributes normally, via a direct call to Kernel.@
    kernel_at(name, meta, args)
  end

  defp kernel_at(name, meta, args) do
    {{:., meta, [{:__aliases__, [alias: false], [:Kernel]}, :@]}, [],
      [{name, [context: Elixir], args}]}
  end

  defp make_is_terminal([state_graph], env) do

    unless StateGraph.valid?(state_graph) do
      raise %CompileError{file: env.file, line: env.line, description: "@state_graph is malformed"}
    end

    terminal_states = StateGraph.terminal_states(state_graph)
    terminal_transitions = StateGraph.terminal_transitions(state_graph)

    original_state_graph = kernel_at(:state_graph, [line: env.line], [state_graph])

    state_typelist = state_graph
    |> StateGraph.states
    |> atoms_to_typelist

    transition_typelist = case StateGraph.transitions(state_graph) do
      [] -> nil
      lst -> atoms_to_typelist(lst)
    end

    quote do
      #rebuild the original
      unquote(original_state_graph)

      @impl true
      defguard is_terminal(state) when state in unquote(terminal_states)

      @impl true
      defguard is_terminal(state, transition) when {state, transition} in unquote(terminal_transitions)

      @type state :: unquote(state_typelist)
      @type transition :: unquote(transition_typelist)
    end
  end

  @spec atoms_to_typelist([atom]) :: Macro.t
  def atoms_to_typelist([state]), do: state
  def atoms_to_typelist([state1, state2]), do: {:|, [], [state1, state2]}
  def atoms_to_typelist([state | rest]), do: {:|, [], [state, atoms_to_typelist(rest)]}

end
