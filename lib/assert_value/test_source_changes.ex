defmodule AssertValue.TestSourceChanges do

  defmodule App do
    use Application
    def start(_type, _args) do
      import Supervisor.Spec, warn: false
      children = [
        worker(AssertValue.TestSourceChanges, [%{}], restart: :temporary)
      ]
      opts = [strategy: :one_for_one]
      Supervisor.start_link(children, opts)
    end
  end

  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def update_lines_count(filename, original_line_number, diff) do
    GenServer.cast __MODULE__, {:update_lines_count, filename, original_line_number, diff}
  end

  def current_line_number(filename, original_line_number) do
    GenServer.call __MODULE__, {:current_line_number, filename, original_line_number}
  end

  def handle_call({:current_line_number, filename, original_line_number}, _from, data) do
    file_changes = data[filename] || %{}
    cumulative_offset = Enum.reduce(file_changes, 0, fn({l,o}, total) ->
      if original_line_number > l, do: total + o, else: total
    end)
    { :reply, original_line_number + cumulative_offset, data }
  end

  def handle_cast({:update_lines_count, filename, original_line_number, diff}, data) do
    file_changes =
      (data[filename] || %{})
      |> Map.put(original_line_number, diff)
    data = Map.put(data, filename, file_changes)
    { :noreply, data }
  end

  def format_status(_reason, [ _pdict, state ]) do
    [data: [{'State', "Saved file offsets: #{inspect state}"}]]
  end
end
