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
    AssertValue.Server.set_captured_ex_unit_io_pid(captured_ex_unit_io_pid)
    {:ok, config}
  end

  def handle_cast(request, state) do
    {:noreply, state} = ExUnit.CLIFormatter.handle_cast(request, state)

    # Do not flush ExUnit IO at the end of the suite
    # ExUnit may close StringIO faster then we try to call it
    case request do
      {:suite_finished, _} -> :ok
      _ -> AssertValue.Server.flush_ex_unit_io()
    end

    {:noreply, state}
  end
end
