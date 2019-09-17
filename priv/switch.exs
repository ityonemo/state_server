defmodule Switch do

  @doc """
  implements a light switch as a state server.  In data, it keeps a count of
  how many times the state of the light switch has changed.
  """

  use StateServer, off: [flip: :on],
                   on:  [flip: :off]

  @type data :: non_neg_integer

  def start_link, do: StateServer.start_link(__MODULE__, :ok)

  @impl true
  def init(:ok), do: {:ok, 0}

  ##############################################################
  ## API ENDPOINTS

  @doc """
  returns the state of switch.
  """
  @spec state(GenServer.server) :: state
  def state(srv), do: GenServer.call(srv, :state)

  @spec state_impl(state) :: StateServer.reply_response
  defp state_impl(state) do
    {:reply, state}
  end

  @doc """
  returns the number of times the switch state has been changed, from either
  flip transitions or by setting the switch value
  """
  @spec count(GenServer.server) :: non_neg_integer
  def count(srv), do: GenServer.call(srv, :count)

  @spec count_impl(non_neg_integer) :: StateServer.reply_response
  defp count_impl(count), do: {:reply, count}

  @doc """
  triggers the flip transition.
  """
  @spec flip(GenServer.server) :: state
  def flip(srv), do: GenServer.call(srv, :flip)

  @spec flip_impl(state, non_neg_integer) :: StateServer.reply_response
  defp flip_impl(:on, count) do
    {:reply, :off, transition: :flip, update: count + 1}
  end
  defp flip_impl(:off, count) do
    {:reply, :on, transition: :flip, update: count + 1}
  end

  @doc """
  sets the state of the switch, without explicitly triggering the flip
  transition.  Note the use of the builtin `t:state/0` type.
  """
  @spec set(GenServer.server, state) :: :ok
  def set(srv, new_state), do: GenServer.call(srv, {:set, new_state})

  @spec set_impl(state, state, data) :: StateServer.reply_response
  defp set_impl(state, state, _) do
    {:reply, state}
  end
  defp set_impl(state, new_state, count) do
    {:reply, state, goto: new_state, update: count + 1}
  end

  ####################################################3
  ## callback routing

  @impl true
  def handle_call(:state, _from, state, _count) do
    state_impl(state)
  end
  def handle_call(:count, _from, _state, count) do
    count_impl(count)
  end
  def handle_call(:flip, _from, state, count) do
    flip_impl(state, count)
  end
  def handle_call({:set, new_state}, _from, state, count) do
    set_impl(state, new_state, count)
  end

  # if we are flipping on the switch, then turn it off after 300 ms
  # to conserve energy.
  @impl true
  def handle_transition(state, transition, _count)
    when is_edge(state, transition, :on) do
    {:noreply, state_timeout: {:conserve, 300}}
  end
  def handle_transition(_, _, _), do: :noreply

  @impl true
  def handle_timeout(:conserve, :on, _count) do
    {:noreply, transition: :flip}
  end
end
