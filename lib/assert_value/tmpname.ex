defmodule AssertValue.Tmpname do

  @moduledoc """
  This module ispired by ruby's tmpname (ruby/lib/tmpdir.rb)
  and elixir Plug's upload.ex
  """

  def generate(prefix \\ "", suffix \\ "") do
    {_mega, sec, micro} = :os.timestamp
    pid = :os.getpid
    random_string = Integer.to_string(:rand.uniform(0x100000000), 36) |> String.downcase
    "#{prefix}#{sec}#{micro}-#{pid}-#{random_string}#{suffix}"
  end

end
