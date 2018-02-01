defmodule AssertValue.Diff do

  @prefixes %{eq: " ", ins: "+", del: "-"}

  def diff(a, b)
      when is_binary(a) and is_binary(b)
      when is_nil(a) and is_binary(b)
      when is_binary(a) and is_nil(b) do
    a = a |> to_string |> AssertValue.StringTools.to_lines
    b = b |> to_string |> AssertValue.StringTools.to_lines
    List.myers_difference(a, b)
    |> format_diff
  end

  def diff(nil, b), do: diff("", inspect(b))
  def diff(a, nil), do: diff(inspect(a), "")
  def diff(a, b), do: diff(inspect(a), inspect(b))

  defp format_diff(diff) do
    diff
    |> Enum.map(fn({k, v}) ->
        Enum.map(v, fn(s) ->
          @prefixes[k] <> s
        end)
      end)
    |> List.flatten
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

end
