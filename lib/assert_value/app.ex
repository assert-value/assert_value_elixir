defmodule AssertValue.App do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # We use custom formatter to temporarily capture and
    # suppress async tests output while interacting with user.
    # persistent: true is used because we may not have ExUnit
    # initialized before this application start.
    Application.put_env(:ex_unit, :formatters, [AssertValue.ExUnitFormatter],
      persistent: true
    )
    children = [
      AssertValue.Server
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
