defmodule AssertValue.Formatter do

  import AssertValue.StringTools

  # Return new expected value and its length in lines
  def new_expected_from_actual(actual, indentation) when is_binary(actual) do
    if length(to_lines(actual)) <= 1 do
      new_string_expected(actual)
    else
      new_heredoc_expected(actual, indentation)
    end
  end

  def new_expected_from_actual(actual, _indentation) do
    {Macro.to_string(actual), 1}
  end

  # Private

  defp new_string_expected(actual) do
    {Macro.to_string(actual), 1}
  end

  defp new_heredoc_expected(actual, indentation) do
    actual =
      actual
      |> add_noeol_if_needed
      |> to_lines
      |> Enum.map(&(indentation <> &1))
      |> Enum.map(&escape_string/1)
    new_expected = ["\"\"\""] ++ actual ++ [indentation <> "\"\"\""]
    {Enum.join(new_expected, "\n"), length(new_expected)}
  end

  # Inspect protocol for String has the best implementation
  # of string escaping. Use it, but remove leading and trailing ?"
  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/inspect.ex
  defp escape_string(s) do
    s
    |> inspect
    |> String.replace(~r/(\A")|("\Z)/, "")
  end

  # to work as a heredoc a string must end with a newline.  For
  # strings that don't we append a special token and a newline when
  # writing them to source file.  This way we can look for this
  # special token when we read it back and strip it at that time.
  defp add_noeol_if_needed(arg) do
    if arg =~ ~r/\n\Z/ do
      arg
    else
      arg <> "<NOEOL>\n"
    end
  end

end
