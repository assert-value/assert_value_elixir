defmodule AssertValue.Formatter do

  import AssertValue.StringTools

  def new_expected_from_actual_value(actual, indentation) do
    if is_binary(actual) and length(to_lines(actual)) > 1 do
      format_as_heredoc(actual, indentation)
    else
      format_as_elixir_code(actual)
    end
  end

  # Private

  defp format_as_elixir_code(actual) do
    # Backported fixed version of Elixir's Macro.to_string
    # This version not to truncate big binaries (>4096 symbols), maps
    # and other big structures
    #
    # TODO: Remove when we drop support of Elixirs <= 1.6.4
    ElixirBackports.MacroToString.to_string(actual)
  end

  defp format_as_heredoc(actual, indentation) do
    actual =
      actual
      |> add_noeol_if_needed
      |> to_lines
      |> Enum.map(&(indentation <> &1))
      |> Enum.map(&escape_heredoc_line/1)
    [~s(""")] ++ actual ++ [indentation <> ~s(""")]
    |> Enum.join("\n")
  end

  # Inspect protocol for String has the best implementation
  # of string escaping. Use it, but remove surrounding quotes
  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/inspect.ex
  defp escape_heredoc_line(s) do
    inspect(s, limit: :infinity, printable_limit: :infinity)
    |> String.replace(~r/(\A"|"\Z)/, "")
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
