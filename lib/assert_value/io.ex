defmodule AssertValue.IO do

  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def handle_cast({:set, key, val}, state) do
    {:noreply, Map.put(state, key, val)}
  end

  def handle_cast({:loop}, state) do
    unless state.mute do
      contents = StringIO.flush(state.proxy_io)
      if contents != "", do: IO.write contents
    end
    loop()
    {:noreply, state}
  end

  def set(key, val) do
    GenServer.cast __MODULE__, {:set, key, val}
  end

  def mute do
    GenServer.cast __MODULE__, {:set, :mute, true}
  end

  def unmute do
    GenServer.cast __MODULE__, {:set, :mute, false}
  end

  def loop() do
    GenServer.cast __MODULE__, {:loop}
  end

end
