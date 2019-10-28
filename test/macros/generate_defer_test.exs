defmodule StateServerTest.Macros.GenerateDeferTest do
  use ExUnit.Case, async: true

  alias StateServer.Macros

  test "generate_defer for handle_call snapshot" do
    assert (~S"""
    foo |> case do
      :defer ->
        if function_exported?(data.module, :__handle_call_shim__, 4) do
          data.module.__handle_call_shim__(payload, from, state, data.data)
        else
          proc = case Process.info(self(), :registered_name) do
            {_, []} ->
              self()
            {_, name} ->
              name
          end
          case :erlang.phash2(1, 1) do
            0 ->
              raise("attempted to call handle_call/4 for StateServer " <> inspect(proc) <> " but no handle_call/4 clause was provided")
            1 ->
              {:stop, {:EXIT, "call error"}}
          end
        end
        {:defer, events} ->
          if function_exported?(data.module, :__handle_call_shim__, 4) do
            data.module.__handle_call_shim__(payload, from, state, data.data)
            |> StateServer.Macros.prepend_events(events)
          else
            proc = case Process.info(self(), :registered_name) do
              {_, []} ->
                self()
              {_, name} ->
                name
            end
            case :erlang.phash2(1, 1) do
              0 ->
                raise("attempted to call handle_call/4 for StateServer " <>
                      inspect(proc) <> " but no handle_call/4 clause was provided")
              1 ->
                {:stop, {:EXIT, "call error"}}
            end
          end
      any ->
        any
    end
    """
    |> Code.string_to_quoted!
    |> Macro.to_string) == (
      Macro.to_string(Macros.generate_handle_call_defer_translation(
        {:foo, [line: 1], nil},
        {:payload, [line: 1], nil},
        {:from, [line: 1], nil},
        {:state, [line: 1], nil},
        {:data, [line: 1], nil})))
  end

  test "generate_defer for arbitrary handler snapshot" do
    assert (~S"""
    foo |> case do
      :defer ->
        if function_exported?(data.module, :__handle_foo_shim__, 3) do
          data.module.__handle_foo_shim__(payload, state, data.data)
        else
          proc = case Process.info(self(), :registered_name) do
            {_, []} ->
              self()
            {_, name} ->
              name
          end
          case :erlang.phash2(1, 1) do
            0 ->
              raise("attempted to call handle_foo/3 for StateServer " <>
                     inspect(proc) <> " but no handle_foo/3 clause was provided")
            1 ->
              {:stop, {:EXIT, "call error"}}
          end
        end
      {:defer, events} ->
        if function_exported?(data.module, :__handle_foo_shim__, 3) do
          data.module.__handle_foo_shim__(payload, state, data.data)
          |> StateServer.Macros.prepend_events(events)
        else
          proc = case Process.info(self(), :registered_name) do
            {_, []} ->
              self()
            {_, name} ->
              name
          end
          case :erlang.phash2(1, 1) do
            0 ->
              raise("attempted to call handle_foo/3 for StateServer " <>
                    inspect(proc) <> " but no handle_foo/3 clause was provided")
            1 ->
              {:stop, {:EXIT, "call error"}}
          end
        end
      any ->
        any
      end
    """
    |> Code.string_to_quoted!
    |> Macro.to_string) == (
      Macro.to_string(Macros.generate_defer_translation(
        {:foo, [line: 1], nil},
        :handle_foo,
        {:payload, [line: 1], nil},
        {:state, [line: 1], nil},
        {:data, [line: 1], nil})))
  end
end
