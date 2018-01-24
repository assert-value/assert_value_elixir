defmodule AssertValue.Parser do

  # This is internal parser error
  # In theory we parse any valid Elixir code and should not face it
  defmodule ParseError do
    defexception [message: "Unable to parse assert_value arguments"]
  end

  # Returns {prefix, expected, suffix, indentation}
  #
  # Split file contents (code) to three parts:
  #   * everything before expected (prefix)
  #   * expected as it is formatted in code include quotes (expected)
  #   * everything after expected (suffix)
  #
  #   code == prefix <> expected <> suffix
  #
  def parse_expected(filename, line_num, assertion_ast, actual_ast, expected_ast) do
    {prefix, suffix} =
      File.read!(filename)
      |> String.split("\n")
      |> Enum.split(line_num - 1)

    prefix = prefix |> Enum.join("\n")
    suffix = suffix |> Enum.join("\n")

    [_, indentation, assert_value, rest] =
      Regex.run(~r/(^\s*)(assert_value\s*)(.*)/s, suffix)

    prefix = prefix <> "\n" <> indentation <> assert_value

    # We enclose parsing in try/rescue because parser code is executed
    # inside genserver. Exceptions raised in genserver produce unreadable
    # Erlang error messages so it is better to pass theese exceptions outside
    # genserver and reraise them to show readable Elixir error messages
    try do
      {assertion, suffix} = get_string_by_ast(rest, assertion_ast)
      {assertion, left_parens, right_parens} = trim_parens(assertion)
      prefix = prefix <> left_parens
      suffix = right_parens <> suffix

      {prefix, rest, suffix} =
        if actual_ast == :_not_present_ do
          {prefix <> assertion, "", suffix}
        else
          {actual, rest} = get_string_by_ast(assertion, actual_ast)
          prefix = prefix <> actual
          {prefix, rest, suffix}
        end

      {prefix, expected, suffix} =
        if expected_ast == :_not_present_ do
          {prefix, "", suffix}
        else
          [_, operator, _, rest] = Regex.run(~r/((\)|\s)+==\s*)(.*)/s, rest)
          prefix = prefix <> operator
          {expected, rest} = get_string_by_ast(rest, expected_ast)
          {prefix, expected, rest <> suffix}
        end

      prefix = if expected_ast == :_not_present_ do
        prefix <> " == "
      else
        prefix
      end

      {prefix, expected, suffix, indentation}
    rescue
      AssertValue.Parser.ParseError ->
        {:error, :parse_error}
    end
  end

  # Private

  # Finds the part of the source with the same AST as second parameter
  # Return pair {accumulator, rest}
  #
  #   iex(1) get_string_by_ast("(1 + 2) == 3", {:+, [], [1, 2]})
  #   #=> {"(1 + 2)", "== 3"}
  #
  # Recursively take one character from source, append it to accumulator, and
  # compare accumulator with code.
  #
  # Corner Case:
  #
  # * floats with trailing zeros
  #   AST for "42.00000" is 42.0
  #   so we need to check that the rest of the source does not contain
  #   leading zeros. They all belong to parsed value
  #
  defp get_string_by_ast(source, ast, accumulator \\ "") do
    if compare_ast(accumulator, ast) && (String.at(source, 0) != "0") do
      {accumulator, source}
    else
      case String.next_grapheme(source) do
        {first_grapheme, rest} ->
          get_string_by_ast(rest, ast, accumulator <> first_grapheme)
        nil ->
          raise AssertValue.Parser.ParseError
      end
    end
  end

  # Returns true if str compiles to the same AST as second parameter
  # There is a corner case for empty string in Elixir < 1.6.0
  #
  #   # Elixir 1.5.3
  #   iex(1)> Code.string_to_quoted(nil)
  #   {:ok, nil}
  #   iex(1)> Code.string_to_quoted("")
  #   {:ok, nil}
  #
  #   # Elixir 1.6.0-rc.0
  #   iex(1)> Code.string_to_quoted(nil)
  #   {:ok, nil}
  #   iex(1)> Code.string_to_quoted("")
  #   {:ok, {:__block__, [], []}}
  #
  # We are sure that when AST is nil it is really nil because we have
  # special :_not_present_ token for empty ASTs
  defp compare_ast(str, ast) do
    case Code.string_to_quoted(str) do
      {:ok, quoted} ->
        quoted = if is_binary(quoted) do
          String.replace(quoted, "<NOEOL>\\n", "")
        else
          quoted
        end
        if remove_lines_meta(quoted) == remove_lines_meta(ast) &&
            !(str == "" && ast == nil) do
          true
        else
          false
        end
      _ ->
        false
    end
  end

  # recursively delete meta information about line numbers from AST
  # iex> remove_lines_meta({:foo, [line: 10], []})
  # {:foo, [], []}
  defp remove_lines_meta(ast) do
    cleaner = &Keyword.delete(&1, :line)
    Macro.prewalk(ast, &Macro.update_meta(&1, cleaner))
  end

  # Try to trim parens and whitespace recursively
  #
  #   trim_parens("  ( (foo  ) ) ")
  #   #=> {"foo", "  ( (", "  ) ) "}
  #
  defp trim_parens(code, left_parens \\ "", right_parens \\ "") do
    regex = ~r/^(\s*\(\s*)(.*)(\s*\)\s*)$/s
    if code =~ regex do
      [_, lp, trimmed, rp] = Regex.run(regex, code)
      # We need to compare code without meta information
      # See comment in a parse_argument above
      if Macro.to_string(Code.string_to_quoted(trimmed)) ==
          Macro.to_string(Code.string_to_quoted(code)) do
        trim_parens(trimmed, left_parens <> lp, rp <> right_parens)
      else
        {code, left_parens, right_parens}
      end
    else
      {code, left_parens, right_parens}
    end
  end

end
