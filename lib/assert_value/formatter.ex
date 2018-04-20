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
    # Temporary (until Elixir 1.6.5) workaround for Macro.to_string()
    # to make it work with big binaries as suggested on Elixir Forum:
    # https://elixirforum.com/t/how-to-increase-printable-limit/13613
    # Without it big binaries (>4096 symbols) are truncated because of bug
    # in Inspect module.
    # TODO Change to plain Macro.to_string() when we drop support for
    # Elixirs < 1.6.5
    Macro.to_string(actual, fn
      node, _ when is_binary(node) ->
        inspect(node, printable_limit: :infinity)
      _, string ->
        string
    end)
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
    inspect(s, printable_limit: :infinity)
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
