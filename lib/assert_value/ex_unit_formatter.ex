defmodule AssertValue.ExUnitFormatter do
  @moduledoc false

  # This module is used to suppress and capture ExUnit's output while waiting
  # for user input on assert_value diffs.  After user's answer we print all
  # collected output.

  # TODO: User may use custom formatter(s) that even don't write to stdout. But
  # we don't know it when this application starts. Find the way to do it at
  # runtime. We should not suppress output other than to stdout and we should
  # not produce extra output when user formatters don't write to stdout.

  use GenServer

  def init(opts) do
    {:ok, config} = ExUnit.CLIFormatter.init(opts)
    # Replace Formatter's io device (group_leader) with StringIO.
    # And tell its pid to AssertValue.Server
    # This will give us control on Formatter's output.
    {:ok, captured_ex_unit_io_pid} = StringIO.open("")
    AssertValue.Server.set_captured_ex_unit_io_pid(captured_ex_unit_io_pid)
    Process.group_leader(self(), captured_ex_unit_io_pid)
    {:ok, config}
  end

  def handle_cast(msg, config) do
    {:noreply, config} = ExUnit.CLIFormatter.handle_cast(msg, config)
    case msg do
      # Notify AssertValue.Server that test is finished.
      # Server may wait for tests with diff to finish its output
      {:test_finished, test} ->
        AssertValue.Server.test_finished({test.tags.file, test.name})
      _ ->
        true
    end
    AssertValue.Server.flush_ex_unit_io()
    {:noreply, config}
  end

end
