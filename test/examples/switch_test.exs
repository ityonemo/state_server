Code.require_file("test/examples/switch.exs")

defmodule StateServerTest.SwitchTest do

  use ExUnit.Case, async: true

  test "switch initialization works" do
    {:ok, srv} = Switch.start_link

    assert :off == Switch.state(srv)
    assert 0 == Switch.count(srv)
  end

  test "switch state can be flipped" do
    {:ok, srv} = Switch.start_link

    Switch.flip(srv)
    assert :on == Switch.state(srv)
    assert 1 == Switch.count(srv)
  end

  test "flipping switch states triggers flipback" do
    {:ok, srv} = Switch.start_link

    Switch.flip(srv)

    Process.sleep(100)
    assert :on == Switch.state(srv)

    Process.sleep(250)
    assert :off == Switch.state(srv)
  end

  test "setting switch does not trigger flipback" do
    {:ok, srv} = Switch.start_link

    Switch.set(srv, :on)
    assert :on == Switch.state(srv)

    Process.sleep(350)
    assert :on == Switch.state(srv)
    assert 1 == Switch.count(srv)
  end

  test "setting switch to self does not increment count" do
    {:ok, srv} = Switch.start_link

    Switch.set(srv, :off)

    assert :off == Switch.state(srv)
    assert 0 == Switch.count(srv)
  end

end
