defmodule StateServer.StateGraph do
  @moduledoc """
  tools for dealing with stategraphs.

  State graphs take the form of a keyword list of keyword lists, wherein the
  outer list is a comprehensive list of the states, and the inner lists are
  keywords list of all the transitions, with the values of the keyword list
  as the destination states.
  """

  @type t :: keyword(keyword(atom))

  @doc """
  checks the validity of the state graph.

  Should only be called when we build the state graph.

  A state graph is valid if and only if all of the following are true:

  0. the graph is a keyword of keywords.
  1. there is at least one state.
  2. there are no duplicate state definitions.
  3. there are no duplicate transition definitions emanating from any given state.
  4. all of the destinations of the transitions are states.
  """
  @spec valid?(t) :: boolean
  def valid?([]), do: false
  def valid?(stategraph) when is_list(stategraph) do
    # check to make sure everything is a keyword of keywords.
    Enum.each(stategraph, fn
      {state, transitions} when is_atom(state) ->
        Enum.each(transitions, fn
          {transition, destination} when
          is_atom(transition) and is_atom(destination) ->
            :ok
          _ -> throw :invalid
        end)
      _ -> throw :invalid
    end)

    state_names = states(stategraph)
    # check to make sure the states are unique.
    state_names == Enum.uniq(state_names) || throw :invalid

    stategraph
    |> Keyword.values
    |> Enum.all?(fn state_transitions ->
      transition_names = Keyword.keys(state_transitions)

      # check to make sure the transition names are unique for each state's transition set.
      transition_names == Enum.uniq(transition_names) || throw :invalid

      # check to make sure that the transition destinations are valid.
      state_transitions
      |> Keyword.values
      |> Enum.all?(&(&1 in state_names))
    end)

  catch
    :invalid -> false
  end
  def valid?(_), do: false

  @doc """
  returns the starting state from the state graph.
  ```elixir
  iex> StateServer.StateGraph.start([start: [t1: :state1], state1: [t2: :state2], state2: []])
  :start
  ```
  """
  @spec start(t) :: atom
  def start([{v, _} | _]), do: v

  @doc """
  lists all states in the state graph.  The first element in this list will
  always be the initial state.

  ### Example
  ```elixir
  iex> StateServer.StateGraph.states([start: [t1: :state1], state1: [t2: :state2], state2: [t2: :state2]])
  [:start, :state1, :state2]
  ```
  """
  @spec states(t) :: [atom]
  def states(stategraph), do: Keyword.keys(stategraph)

  @doc """
  lists all transitions in the state graph.

  ### Example
  ```elixir
  iex> StateServer.StateGraph.transitions([start: [t1: :state1], state1: [t2: :state2], state2: [t2: :state2]])
  [:t1, :t2]
  ```
  """
  @spec transitions(t) :: [atom]
  def transitions(stategraph) do
    stategraph
    |> Keyword.values
    |> Enum.flat_map(&Keyword.keys/1)
    |> Enum.uniq
  end

  @doc """
  lists all transitions emanating from a given state.

  ### Example
  ```elixir
  iex> StateServer.StateGraph.transitions([start: [t1: :state1, t2: :state2], state1: [], state2: []], :start)
  [:t1, :t2]
  ```
  """
  @spec transitions(t, atom) :: [atom]
  def transitions(stategraph, state), do: Keyword.keys(stategraph[state])

  @doc """
  lists all state/transition pairs. Used to generate the `c:StateServer.is_transition/2` guard.

  ### Example
  ```elixir
  iex> StateServer.StateGraph.all_transitions([start: [t1: :state1, t2: :state2], state1: [], state2: [t2: :state1]])
  [start: :t1, start: :t2, state2: :t2]
  ```
  """
  @spec all_transitions(t) :: keyword
  def all_transitions(stategraph) do
    stategraph
    |> Enum.flat_map(fn
      {st, trs} -> Enum.map(trs, fn {tr, _dest} -> {st, tr} end)
    end)
  end

  @doc """
  outputs the destination state given a source state and a transition.

  ### Example
  ```elixir
  iex> StateServer.StateGraph.transition([start: [t1: :state1, t2: :state2], state1: [], state2: []], :start, :t1)
  :state1
  ```
  """
  @spec transition(t, start::atom, transition::atom) :: atom
  def transition(stategraph, start, transition) do
    stategraph
    |> Keyword.get(start)
    |> Keyword.get(transition)
  end

  @doc """
  outputs a list of terminal states of the graph.  Used to generate the
  `c:StateServer.is_terminal/1` guard.

  ```elixir
  iex> StateServer.StateGraph.terminal_states(start: [t1: :state1, t2: :state2], state1: [], state2: [])
  [:state1, :state2]
  ```
  """
  @spec terminal_states(t) :: [atom]
  def terminal_states(stategraph) do
    Enum.flat_map(stategraph, fn
      {state, []} -> [state]
      _ -> []
    end)
  end

  @doc """
  outputs a list of edges of the graph.  Used to generate the `c:StateServer.is_transition/3` guard.

  ```elixir
  iex> StateServer.StateGraph.edges(start: [t1: :state1, t2: :state2], state1: [t3: :start], state2: [])
  [start: {:t1, :state1}, start: {:t2, :state2}, state1: {:t3, :start}]
  ```
  """
  @spec edges(t) :: keyword({atom, atom})
  def edges(state_graph) do
    Enum.flat_map(state_graph, fn
      {_, []} -> []
      {state, transitions} ->
        Enum.flat_map(transitions, fn
          {transition, dest} ->
            [{state, {transition, dest}}]
        end)
      _ -> []
    end)
  end

  @doc """
  outputs a list of terminal {state, transition} tuples of the graph.  Used to generate the
  `c:StateServer.is_terminal/2` guard.

  ```elixir
  iex> StateServer.StateGraph.terminal_transitions(start: [t1: :state1, t2: :state2], state1: [], state2: [])
  [start: :t1, start: :t2]
  ```
  """
  @spec terminal_transitions(t) :: keyword(atom)
  def terminal_transitions(stategraph) do
    t_states = terminal_states(stategraph)
    Enum.flat_map(stategraph, &transitions_for_state(&1, t_states))
  end

  @spec transitions_for_state({atom, keyword(atom)}, [atom]) :: keyword(atom)
  defp transitions_for_state({state, trs}, t_states) do
    Enum.flat_map(trs, fn {tr, dest} ->
      if dest in t_states, do: [{state, tr}], else: []
    end)
  end

  @doc """
  converts a list of atoms to a type which is the union of the atom literals
  """
  @spec atoms_to_typelist([atom]) :: Macro.t
  def atoms_to_typelist([]), do: nil
  def atoms_to_typelist([state]), do: state
  def atoms_to_typelist([state1, state2]), do: {:|, [], [state1, state2]}
  def atoms_to_typelist([state | rest]), do: {:|, [], [state, atoms_to_typelist(rest)]}
end
