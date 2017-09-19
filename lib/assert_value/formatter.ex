defmodule AssertValue.Formatter do
  @moduledoc false
  use GenServer

  def init(opts) do
    {:ok, config} = ExUnit.CLIFormatter.init(opts)
    AssertValue.IO.set(:original_io, Process.group_leader())
    {:ok, proxy_io} = StringIO.open("")
    AssertValue.IO.set(:proxy_io, proxy_io)
    Process.group_leader(self(), proxy_io)
    AssertValue.IO.loop()
    {:ok, config}
  end

  defdelegate handle_cast(data, config), to: ExUnit.CLIFormatter

end
