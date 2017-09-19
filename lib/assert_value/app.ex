defmodule AssertValue.App do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # We use custom formatter to capture and suppress
    # async tests output while interacting with user.
    # Config.persist is used because we may not have
    # ExUnit config initialized on application start.
    # TODO: Find the way to do it at runtime
    # TODO: Do not turn off user's custom formatters
    # (different from ExUnit.CLIFormatter)
    Mix.Config.persist(ex_unit: [formatters: [AssertValue.Formatter]])
    children = [
      worker(AssertValue.IO, [%{mute: false}]),
      worker(AssertValue.Server, [%{}], restart: :temporary)
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
