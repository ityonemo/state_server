defmodule StateServerTest.EtcTest do

  use ExUnit.Case, async: true

  @moduletag :calltests

  describe "when making calls" do
    # positive controls: GenServer.call and :gen_statem.call
    test "GenServer.call has a normal pid ref" do

      inner_pid = spawn(fn ->
        from = {from_pid, _ref} = receive do {:"$gen_call", from, :call} -> from end
        GenServer.reply(from, from_pid)
      end)

      from_pid = GenServer.call(inner_pid, :call)

      assert self() == from_pid
    end

    test "GenServer.call with timeout has a normal pid ref" do

      inner_pid = spawn(fn ->
        from = {from_pid, _ref} = receive do {:"$gen_call", from, :call} -> from end
        GenServer.reply(from, from_pid)
      end)

      from_pid = GenServer.call(inner_pid, :call, 5000)

      assert self() == from_pid
    end

    test ":gen_statem.call with timeout has an abnormal pid ref" do

      inner_pid = spawn(fn ->
        from = {from_pid, _ref} = receive do {:"$gen_call", from, :call} -> from end
        :gen_statem.reply(from, from_pid)
      end)

      from_pid = :gen_statem.call(inner_pid, :call, 5000)

      refute self() == from_pid
    end

    test ":gen_statem.call has a normal pid ref" do

      inner_pid = spawn(fn ->
        from = {from_pid, _ref} = receive do {:"$gen_call", from, :call} -> from end
        :gen_statem.reply(from, from_pid)
      end)

      from_pid = :gen_statem.call(inner_pid, :call)

      assert self() == from_pid
    end

    test "StateServer.call without a timeout has a normal pid ref" do

      inner_pid = spawn(fn ->
        from = {from_pid, _ref} = receive do {:"$gen_call", from, :call} -> from end
        StateServer.reply(from, from_pid)
      end)

      from_pid = StateServer.call(inner_pid, :call)

      assert self() == from_pid
    end
  end

end
