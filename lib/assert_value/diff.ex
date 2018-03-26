defmodule AssertValue.Diff do

  @prefixes %{eq: " ", ins: "+", del: "-"}

  def diff(a, b) when is_binary(a) and is_binary(b) do
    a = AssertValue.StringTools.to_lines(a)
    b = AssertValue.StringTools.to_lines(b)
    List.myers_difference(a, b)
    |> format_diff
  end

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
