defmodule AssertValue.App do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(AssertValue.FileTracker, [%{}], restart: :temporary)
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
