Code.require_file("example/switch_with_states.exs")

defmodule StateServerTest.SwitchWithStatesTest do

  use ExUnit.Case
  import ExUnit.CaptureIO

  @tag :one
  test "SwitchWithStates announces flips" do
    {:ok, srv} = SwitchWithStates.start_link

    assert "state is off" == SwitchWithStates.query(srv)

    assert capture_io(:stderr, fn ->
      SwitchWithStates.flip(srv)
      Process.sleep(100)
    end) =~ "flipped on"

    assert "state is on" == SwitchWithStates.query(srv)

    assert capture_io(:stderr, fn ->
      SwitchWithStates.flip(srv)
      # IO is async, so we must wait
      Process.sleep(100)
    end) =~ "flipped off"

    assert "state is off" == SwitchWithStates.query(srv)
  end

end
