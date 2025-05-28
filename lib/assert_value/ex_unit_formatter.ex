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
    # Get ExUnit's Formatter io device pid and tell it to AssertValue.Server
    # We will use it to flush ExUnit's output before interactions with user
    {:ok, captured_ex_unit_io_pid} = StringIO.open("")

    Process.group_leader()
    |> AssertValue.Server.set_original_group_leader()

    AssertValue.Server.set_captured_ex_unit_io_pid(captured_ex_unit_io_pid)
    # This will redirect all stdout IO to our capturing StringIO
    Process.group_leader(self(), captured_ex_unit_io_pid)
    {:ok, config}
  end

  def handle_cast(request, state) do
    {:noreply, state} = ExUnit.CLIFormatter.handle_cast(request, state)

    case request do
      # Do not flush ExUnit IO at the end of the suite
      # ExUnit may close StringIO faster than we try to call it
      {:suite_finished, _} ->
        :ok

      # Notify AssertValue.Server that test is finished,
      # so it will process and flush all pending outputs
      {:test_finished, test} ->
        AssertValue.Server.test_finished({test.tags.file, test.name})

      _ ->
        AssertValue.Server.flush_ex_unit_io()
    end

    {:noreply, state}
  end

  def terminate(_reason, _state) do
    AssertValue.Server.flush_ex_unit_io()
    # Bring back original :stdout IO on terminate
    # otherwise we may lose some finishing output
    # (like "Finished in...", "X tests, Y failures...", etc)
    Process.group_leader(self(), AssertValue.Server.get_original_group_leader())
    :ok
  end
end
