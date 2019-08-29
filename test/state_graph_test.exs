defmodule StateServerTest.StateGraphTest do
  use ExUnit.Case, async: true

  alias StateServer.StateGraph

  doctest StateGraph

  describe "when sent to valid?/1" do
    test "basic normal state graphs are alright" do
      assert StateGraph.valid?([foo: [bar: :foo]])
      assert StateGraph.valid?([foo: [bar: :baz], baz: []])
      assert StateGraph.valid?([foo: [bar: :baz, quux: :nix], baz: [quux: :nix], nix: []])
    end

    test "non-keywords are invalid" do
      refute StateGraph.valid?("hello")
    end

    test "condition 0: ill-formed keys are invalid" do
      refute StateGraph.valid?([{"hello", [bar: :baz]}])
      refute StateGraph.valid?([{"hello", [bar: :baz], "coo"}])
    end

    test "condition 1: an empty state graph is invalid" do
      refute StateGraph.valid?([])
    end

    test "condition 2: duplicate states make a state graph invalid" do
      refute StateGraph.valid?([foo: [], foo: []])
    end

    test "condition 3: duplicate transitions within a state make a state graph invalid" do
      refute StateGraph.valid?([foo: [bar: :foo, bar: :foo]])
    end

    test "condition 4: nonexisting destination states from a transition make a state graph invalid" do
      refute StateGraph.valid?([foo: [bar: :baz]])
    end
  end

  describe "stategraph is able to find properties" do
    test "start/1" do
      assert :foo == StateGraph.start([foo: []])
      assert :foo == StateGraph.start([foo: [bar: :baz], baz: []])
    end

    test "states/1" do
      assert [:foo] == StateGraph.states([foo: []])
      assert [:foo] == StateGraph.states([foo: [bar: :foo]])
      assert [:foo, :baz] == StateGraph.states([foo: [bar: :baz], baz: []])
    end

    test "transitions/1" do
      assert [] == StateGraph.transitions([foo: []])
      assert [:bar] == StateGraph.transitions([foo: [bar: :foo]])
      assert [:bar, :quux] == StateGraph.transitions([foo: [bar: :baz], baz: [quux: :foo]])

      # duplicated transitions are not duplicated in the result.
      assert [:bar, :quux] == StateGraph.transitions([foo: [bar: :baz], baz: [bar: :baz, quux: :foo]])
    end

    test "transitions/2" do
      assert [] == StateGraph.transitions([foo: []], :foo)
      assert [:bar] == StateGraph.transitions([foo: [bar: :foo]], :foo)
      assert [:bar, :quux] == StateGraph.transitions(
        [foo: [bar: :baz, quux: :foo], baz: [quux: :foo]], :foo)
    end
  end

end
