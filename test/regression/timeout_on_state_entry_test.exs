defmodule StateServerTest.Regression.TimeoutOnStateEntryTest do
  # regression identified 12 Feb 2020, issue with timeouts and
  # on state entry clauses.

  use ExUnit.Case, async: true

  defmodule TestServer do
    use StateServer, [start: [],
                      end: [tr: :end]]

    def start_link(resp_pid), do: StateServer.start_link(__MODULE__, resp_pid)

    @impl true
    def init(resp_pid), do: {:ok, resp_pid, goto: :end}

    @impl true
    def on_state_entry(transition, :end, resp_pid) do
      send(resp_pid, transition || :foo)
      {:noreply, state_timeout: {:timeout, 50}}
    end

    @impl true
    def handle_timeout(:timeout, :end, resp_pid) do
      send(resp_pid, :timed_out)
      {:noreply, transition: :tr}
    end
  end

  test "the test server will send two foos separated by 150ms" do
    {:ok, _srv} = TestServer.start_link(self())

    # get the first foo back
    assert_receive :foo
    assert_receive :timed_out
    assert_receive :tr
  end

end

