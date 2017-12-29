defmodule AssertValue.StringTools do

  def to_lines(arg) do
    arg
    # remove trailing newline otherwise String.split will give us an
    # empty line at the end
    |> String.replace(~r/\n\Z/, "", global: false)
    |> String.split("\n")
  end

  def smart_truncate(s, length) when is_binary(s) and length > 0 do
    if String.length(s) <= length do
      s
    else
      s
      |> String.slice(0..length - 1)
      |> Kernel.<>("...")
    end
  end

end
