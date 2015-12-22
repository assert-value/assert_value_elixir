defmodule AssertValue.FileOffsets do
  use GenServer

  @moduledoc ~S"""
  ## Usage

      iex> import AssertValue.FileOffsets
      nil
      iex> get_file_offset("~/test.exs")
      0
      iex> set_file_offset("~/test.exs", -2)
      :ok
      iex> get_file_offset("~/test.exs")
      -2
  """

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def set_file_offset(filename, offset) do
    GenServer.cast __MODULE__, {:set_file_offset, filename, offset}
  end

  def get_file_offset(filename) do
    GenServer.call __MODULE__, {:get_file_offset, filename}
  end

  def handle_call({:get_file_offset, filename}, _from, data) do
    { :reply, (data[filename] || 0), data }
  end

  def handle_cast({:set_file_offset, filename, offset}, data) do
    { :noreply, Map.put(data, filename, offset)}
  end

  def format_status(_reason, [ _pdict, state ]) do
    [data: [{'State', "Saved file offsets: #{inspect state}"}]]
  end
end

defmodule AssertValue.FileOffsets.App do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(AssertValue.FileOffsets, [%{}])
    ]
    opts = [strategy: :one_for_one]

    Supervisor.start_link(children, opts)
  end
end
