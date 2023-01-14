defmodule AssertValue.Formatter do
  import AssertValue.StringTools

  def new_expected_from_actual_value(actual) do
    if is_binary(actual) and length(to_lines(actual)) > 1 do
      format_as_heredoc(actual)
    else
      actual
      |> Kernel.inspect(limit: :infinity, printable_limit: :infinity)
      |> Code.format_string!()
      |> IO.iodata_to_binary()
    end
  end

  def format_with_indentation(code, indentation, formatter_opts) do
    # 98 is default Elixir line length
    line_length = Keyword.get(formatter_opts, :line_length, 98)
    # Reduce line length to indentation
    # Since we format only assert_value statement, formatter will unindent
    # it as it is the only statement in all code. When we add indentation
    # back, line length may exceed limits.
    line_length = line_length - String.length(indentation)
    formatter_opts = Keyword.put(formatter_opts, :line_length, line_length)

    code
    |> Code.format_string!(formatter_opts)
    |> IO.iodata_to_binary()
    |> to_lines
    |> Enum.map_join("\n", &indent_heredoc_line(&1, indentation))
  end

  # Private

  defp format_as_heredoc(actual) do
    actual =
      actual
      |> add_noeol_if_needed
      |> to_lines
      |> Enum.map(&escape_heredoc_line/1)

    ([~s(""")] ++ actual ++ [~s(""")])
    |> Enum.join("\n")
  end

  # Inspect protocol for String has the best implementation
  # of string escaping. Use it, but remove surrounding quotes
  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/inspect.ex
  defp escape_heredoc_line(s) do
    inspect(s, printable_limit: :infinity)
    |> String.replace(~r/(\A"|"\Z)/, "")
  end

  # "mix format" does not indent empty lines in heredocs
  defp indent_heredoc_line(s, indentation) do
    if(s == "", do: s, else: indentation <> s)
  end

  # to work as a heredoc a string must end with a newline.  For
  # strings that don't we append a special token and a newline when
  # writing them to source file.  This way we can look for this
  # special token when we read it back and strip it at that time.
  defp add_noeol_if_needed(arg) do
    if String.at(arg, -1) == "\n" do
      arg
    else
      arg <> "<NOEOL>\n"
    end
  end
end
