defmodule AssertValue.App do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # We use custom formatter to temporarily capture and
    # suppress async tests output while interacting with user.
    # Config.persist is used because we may not have ExUnit
    # config initialized before this application start.
    Mix.Config.persist(ex_unit: [formatters: [AssertValue.ExUnitFormatter]])
    children = [
      AssertValue.Server
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
