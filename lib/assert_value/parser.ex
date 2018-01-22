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
  # Also returns line indentation to create new expected value heredoc
  #
  # assertion_code, actual_code, and expected_code are strings representing
  # ASTs got from assert_value macro.
  def parse_expected(filename, line_num, assertion_code, actual_code \\ nil, expected_code \\ nil) do
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
      {assertion, suffix} = parse_code(rest, assertion_code)
      {assertion, left_parens, right_parens} = trim_parens(assertion)
      prefix = prefix <> left_parens
      suffix = right_parens <> suffix

      {prefix, rest, suffix} =
        if actual_code do
          {actual, rest} = parse_code(assertion, actual_code)
          prefix = prefix <> actual
          {prefix, rest, suffix}
        else
          {prefix <> assertion, "", suffix}
        end

      {prefix, expected, suffix} =
        if expected_code do
          [_, operator, _, rest] = Regex.run(~r/((\)|\s)+==\s*)(.*)/s, rest)
          prefix = prefix <> operator
          {expected, rest} = parse_code(rest, expected_code)
          {prefix, expected, rest <> suffix}
        else
          {prefix, "", suffix}
        end

      prefix = if expected_code, do: prefix, else: prefix <> " == "

      {prefix, expected, suffix, indentation}
    rescue
      AssertValue.Parser.ParseError ->
        {:error, :parse_error}
    end
  end

  # Private

  # Finds the part of the source with AST matching AST of the code
  # Return pair {result, rest}
  #
  #   iex(1) parse_code("(1 + 2) == 3", "1 + 2")
  #   #=> {"(1 + 2)", "== 3"}
  #
  # Recursively take one character from source, append it to result, and
  # compare result with code.
  #
  # NOTE: We are sure that there are no surrounding parens aroung source
  #
  # NOTE: There may be differences between AST evaluated from string and
  # the one from compiler for complex values because of line numbers, etc...
  #
  #   iex(1)> a = [c: {:<<>>, [line: 1], [1, 2, 2]}]
  #   iex(2)> b = [c: <<1, 2, 2>>]
  #
  #   iex(3)> a == b
  #   false
  #
  # To deal with it compare formatted ASTs
  #
  #   iex(4)> Macro.to_string(a) == Macro.to_string(b)
  #   true
  #
  # NOTE: Corner Cases
  #
  # * result is empty string and code is "nil":
  #
  #   # Elixir 1.5.3
  #   iex(1)> Code.string_to_quoted(nil)
  #   {:ok, nil}
  #   iex(1)> Code.string_to_quoted("")
  #   {:ok, nil}
  #   iex(2)> Macro.to_string(nil)
  #   "nil"
  #
  #   # Elixir 1.6.0-rc.0
  #   iex(1)> Code.string_to_quoted(nil)
  #   {:ok, nil}
  #   iex(1)> Code.string_to_quoted("")
  #   {:ok, {:__block__, [], []}}
  #   iex(2)> Macro.to_string({:__block__, [], []})
  #   "(\n  \n)"
  #
  # * floats with trailing zeros
  #   Since 42.0 is equal 42.0000 we should always
  #   check that the rest of the source does not contain leading
  #   zeros. They all belong to parsed value
  #
  defp parse_code(source, code, result \\ "") do
    {_, value} = Code.string_to_quoted(result)
    value = if is_binary(value) && String.match?(value, ~r/<NOEOL>/) do
      # In quoted code newlines are quoted
      String.replace(value, "<NOEOL>\\n", "")
    else
      value
    end
    if Macro.to_string(value) == code &&
        !(result == "" && code == "nil") &&
        !(source =~ ~r/^0+(\s|$)/s) do
      {result, source}
    else
      case String.next_grapheme(source) do
        {char, rest} ->
          parse_code(rest, code, result <> char)
        nil ->
          raise AssertValue.Parser.ParseError
      end
    end
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
