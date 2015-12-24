defmodule AssertValue.Diff do

  @prefixes %{eq: " ", ins: "+", del: "-"}

  def diff(a, b) do
    a = to_string_list a
    b = to_string_list b
    format_diff :tdiff.diff(a, b)
  end

  defp to_string_list(value) do
    value
    |> to_string
    |> String.replace(~r/\n$/, "", global: false)
    |> String.split("\n")
  end

  defp format_diff(diff) do
    formatted =
      diff
      |> Enum.map(fn({k,v}) ->
          Enum.map(v, fn(s) ->
            @prefixes[k] <> s
          end)
        end)
      |> List.flatten
      |> Enum.join("\n")
    (formatted <> "\n")
  end

end
