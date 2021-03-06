defmodule StateServer.Macros do

  @moduledoc false

  defmacro default_handler([{name, arity}]) do
    generate_handler(name, arity)
  end

  @spec generate_handler(atom, non_neg_integer) :: Macro.t
  def generate_handler(name, arity) do
    params = Enum.map(1..arity, fn _ -> {:_, [], Elixir} end)

    # block comes from GenServer implementation
    block = default_failure_code(name, arity)

    handler_fn = {:def,
      [context: __MODULE__, import: Kernel],
      [{name, [context: __MODULE__], params}, [do: block]]}

    quote do
      @doc false
      unquote(handler_fn)
    end
  end

  defp default_failure_code(name, arity) do

    fun = "#{name}/#{arity}"

    prefix = "attempted to call #{fun} for StateServer "
    postfix = " but no #{fun} clause was provided"

    quote do
      proc = case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

      case :erlang.phash2(1, 1) do
        0 ->
          raise unquote(prefix) <> inspect(proc) <> unquote(postfix)
        1 ->
          {:stop, {:EXIT, "call error"}}
      end
    end
  end

  defmacro do_delegate_translation(prev, :handle_call, payload, from, state, data) do
    generate_handle_call_delegate_translation(prev, payload, from, state, data)
  end

  @spec generate_handle_call_delegate_translation(Macro.t, Macro.t, Macro.t, Macro.t, Macro.t) :: Macro.t
  def generate_handle_call_delegate_translation(prev, payload, from, state, data) do
    default_handler_code = default_failure_code(:handle_call, 4)
    quote do
      unquote(prev)
      |> case do
        de when de in [:defer, :delegate] ->
          if function_exported?(unquote(data).module, :__handle_call_shim__, 4) do
            unquote(data).module.__handle_call_shim__(unquote(payload),
                                                      unquote(from),
                                                      unquote(state),
                                                      unquote(data).data)
          else
            unquote(default_handler_code)
          end
        {de, events = [{type, _}, {:update, new_data} | _]}
            when type in [:goto, :transition] and de in [:defer, :delegate]->
          if function_exported?(unquote(data).module, :__handle_call_shim__, 4) do
            unquote(data).module.__handle_call_shim__(unquote(payload),
                                                      unquote(from),
                                                      unquote(state),
                                                      new_data)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        {de, events = [{:update, new_data} | _]} when de in [:defer, :delegate]->
          if function_exported?(unquote(data).module, :__handle_call_shim__, 4) do
            unquote(data).module.__handle_call_shim__(unquote(payload),
                                                      unquote(from),
                                                      unquote(state),
                                                      new_data)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        {de, events} when de in [:defer, :delegate]->
          if function_exported?(unquote(data).module, :__handle_call_shim__, 4) do
            unquote(data).module.__handle_call_shim__(unquote(payload),
                                                      unquote(from),
                                                      unquote(state),
                                                      unquote(data).data)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        any -> any
      end
    end
  end

  defmacro do_delegate_translation(prev, fun, payload, state, data) do
    generate_delegate_translation(prev, fun, payload, state, data)
  end

  @spec generate_delegate_translation(Macro.t, atom, Macro.t, Macro.t, Macro.t) :: Macro.t
  def generate_delegate_translation(prev, fun, payload, state, data) do
    default_handler_code = default_failure_code(fun, 3)
    shim_fn = state_shim_for(fun)
    quote do
      unquote(prev)
      |> case do
        de when de in [:defer, :delegate] ->
          if function_exported?(unquote(data).module, unquote(shim_fn), 3) do
            unquote(data).module.unquote(shim_fn)(unquote(payload), unquote(state), unquote(data).data)
          else
            unquote(default_handler_code)
          end
        {de, events = [{type, _}, {:update, new_state} | _]}
            when type in [:goto, :transition] and de in [:defer, :delegate] ->
          if function_exported?(unquote(data).module, unquote(shim_fn), 3) do
            unquote(data).module.unquote(shim_fn)(
              unquote(payload),
              unquote(state),
              new_state)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        {de, events = [{:update, new_state} | _]} when de in [:defer, :delegate]  ->
          if function_exported?(unquote(data).module, unquote(shim_fn), 3) do
            unquote(data).module.unquote(shim_fn)(
              unquote(payload),
              unquote(state),
              new_state)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        {de, events} when de in [:defer, :delegate] ->
          if function_exported?(unquote(data).module, unquote(shim_fn), 3) do
            unquote(data).module.unquote(shim_fn)(unquote(payload), unquote(state), unquote(data).data)
            |> StateServer.Macros.prepend_events(events)
          else
            unquote(default_handler_code)
          end
        any -> any
      end
    end
  end

  @handlers [:handle_cast, :handle_continue, :handle_info, :handle_internal,
    :handle_timeout, :handle_transition, :on_state_entry, :terminate]

  defmacro ignore(handler) when handler in @handlers do
    quote do
      def unquote(handler)(_, _), do: :noreply
    end
  end

  @spec state_shim_for(atom) :: atom
  def state_shim_for(fun) do
    String.to_atom("__" <> Atom.to_string(fun) <> "_shim__")
  end

  def prepend_events({:reply, term}, events), do: {:reply, term, events}
  def prepend_events({:reply, term, called_events}, events), do: {:reply, term, events ++ called_events}
  def prepend_events(:noreply, events), do: {:noreply, events}
  def prepend_events({:noreply, called_events}, events), do: {:noreply, events ++ called_events}

end
