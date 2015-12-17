defmodule AssertValue do

  @prefixes %{eq: " ", ins: "+", del: "-"}

  def diff(a, b) do
    a = to_string_list a
    b = to_string_list b
    format_diff :tdiff.diff(a, b)
  end

  defp to_string_list(string_or_char_list) do
    string_or_char_list
    |> to_string
    |> String.rstrip(?\n)
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
    (formatted <> "\n") |> to_char_list
  end

end
