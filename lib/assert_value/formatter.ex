defmodule AssertValue.Formatter do
  @moduledoc false
  use GenServer

  def init(opts) do
    {:ok, config} = ExUnit.CLIFormatter.init(opts)
    # Replace Formatter's io device (group_leader) with StringIO.
    # And tell its pid to AssertValue.Server
    # This will give us control on Formatter's output.
    original_io_pid = Process.group_leader()
    {:ok, captured_io_pid} = StringIO.open("")
    AssertValue.Server.set_io_pids(original_io_pid, captured_io_pid)
    Process.group_leader(self(), captured_io_pid)
    AssertValue.Server.loop()
    {:ok, config}
  end

  defdelegate handle_cast(test, config), to: ExUnit.CLIFormatter

end
