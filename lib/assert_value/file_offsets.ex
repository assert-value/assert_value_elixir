defmodule AssertValue.FileOffsets do

  defmodule App do
    use Application
    def start(_type, _args) do
      import Supervisor.Spec, warn: false
      children = [
        worker(AssertValue.FileOffsets, [%{}], restart: :temporary)
      ]
      opts = [strategy: :one_for_one]
      Supervisor.start_link(children, opts)
    end
  end

  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def set_line_offset(filename, line, offset) do
    GenServer.cast __MODULE__, {:set_line_offset, filename, line, offset}
  end

  def get_line_offset(filename, line) do
    GenServer.call __MODULE__, {:get_line_offset, filename, line}
  end

  def handle_call({:get_line_offset, filename, line}, _from, data) do
    file_offsets = data[filename] || %{}
    offset = Enum.reduce(file_offsets, 0, fn({l,o}, total) ->
      if line > l, do: total + o, else: total
    end)
    { :reply, offset, data }
  end

  def handle_cast({:set_line_offset, filename, line, offset}, data) do
    file_offsets =
      (data[filename] || %{})
      |> Map.put(line, offset)
    data = Map.put(data, filename, file_offsets)
    { :noreply, data }
  end

  def format_status(_reason, [ _pdict, state ]) do
    [data: [{'State', "Saved file offsets: #{inspect state}"}]]
  end
end
