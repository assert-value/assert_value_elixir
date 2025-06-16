defmodule AssertValue.ExUnitFormatter do
  @moduledoc false

  # This module is used to flush all ExUnit's output collected by
  # other tests running in parallel before interacting with user so
  # their output will not mix on screen.

  # TODO: User may use custom formatter(s) that even don't write to stdout.
  # In the best case this module will do nothing, otherwise it may raise
  # unexpected errors

  use GenServer

  def init(opts) do
    {:ok, config} = ExUnit.CLIFormatter.init(opts)

    Process.group_leader()
    |> AssertValue.Server.set_original_group_leader()

    # This will redirect all stdout IO to AssertValue.Server
    Process.group_leader(self(), AssertValue.Server.get_pid())

    {:ok, config}
  end

  def handle_cast(request, state) do
    {:noreply, state} = ExUnit.CLIFormatter.handle_cast(request, state)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    # Bring back original :stdout IO on terminate
    # otherwise we may lose some finishing output
    # (like "Finished in...", "X tests, Y failures...", etc)
    Process.group_leader(self(), AssertValue.Server.get_original_group_leader())
    :ok
  end
end
