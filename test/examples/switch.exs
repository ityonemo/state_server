defmodule Switch do
  use StateServer, state_graph: [off: [flip: :on],
                                 on:  [flip: :off]]

  @type data :: non_neg_integer

  def start_link(_) do
    StateServer.start_link(__MODULE__, :ok)
  end

  @impl true
  def init(:ok) do
    {:ok, 0}
  end

  ##############################################################
  ## API ENDPOINTS

  @doc """
  returns the state of switch.
  """
  @spec state(GenServer.server) :: state
  def state(srv), do: GenServer.call(srv, :state)

  @spec state_impl(state) :: reply
  defp state_impl(state) do
    {:reply, state}
  end

  @doc """
  returns the number of times the switch state has been changed, from either
  flip transitions or by setting the switch value
  """
  @spec count(GenServer.server) :: non_neg_integer
  def count(srv), do: GenServer.call(srv, :count)

  @spec count_impl(non_neg_integer) :: reply
  defp count_impl(count) do
    {:reply, count}
  end

  @doc """
  triggers the flip transition.
  """
  @spec flip(GenServer.server) :: state
  def flip(srv), do: GenServer.call(srv, :flip)

  @spec flip_impl(state, non_neg_integer) :: reply
  defp flip_impl(:on, count) do
    {:reply, :off, transition: :flip, update: count + 1}
  end
  defp flip_impl(:off, count) do
    {:reply, :on, transition: :flip, update: count + 1}
  end

  @doc """
  sets the state of the switch, without explicitly triggering the flip
  transition.
  """
  @spec set(GenServer.server, state) :: :ok
  def set(srv, new_state), do: GenServer.call(srv, {:set, new_state})

  @spec set_impl(state, state) :: reply
  defp set_impl(state, state) do
    {:reply, state}
  end
  defp set_impl(state, new_state) do
    {:reply, state, goto: new_state, update: count + 1}
  end

  ####################################################3
  ## callback routing

  @impl true
  def handle_call(:state, _from, state, _data) do
    state_impl(state)
  end
  def handle_call(:count, _from, _state, data) do
    count_impl(data)
  end
  def handle_call(:flip, _from, state, data) do
    flip_impl(state, data)
  end
  def handle_call({:set, new_state}, _from, state, data) do
    set_impl(state, new_state)
  end
end
