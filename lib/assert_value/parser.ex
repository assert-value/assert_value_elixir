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
  def parse_expected(
    filename, line_num, assertion_ast, actual_ast, expected_ast
  ) do
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
      {assertion, suffix} = find_ast_in_code(rest, assertion_ast)
      {assertion, left_parens, right_parens} = trim_parens(assertion)
      prefix = prefix <> left_parens
      suffix = right_parens <> suffix

      {prefix, rest, suffix} =
        if actual_ast == :_not_present_ do
          # If assertion is comparison operator (except == and ===)
          # then wrap it in parens before appending "== <expected>"
          # This will produce code with correct operation precedence
          case assertion_ast do
            {operator, _, _}
                when operator in [:=, :!=, :>, :<, :>=, :<=, :=~] ->
              {prefix <> "(" <> assertion <> ")", "", suffix}
            _ ->
              {prefix <> assertion, "", suffix}
          end
        else
          {actual, rest} = find_ast_in_code(assertion, actual_ast)
          {prefix <> actual, rest, suffix}
        end

      {prefix, expected, suffix} =
        if expected_ast == :_not_present_ do
          {prefix <> " == ", "", suffix}
        else
          [_, operator, _, rest] = Regex.run(~r/((\)|\s)*=+\s*)(.*)/s, rest)
          {expected, rest} = find_ast_in_code(rest, expected_ast)
          {prefix <> operator, expected, rest <> suffix}
        end

      {prefix, expected, suffix, indentation}
    rescue
      AssertValue.Parser.ParseError ->
        {:error, :parse_error}
    end
  end

  # Private

  # Finds the part of the code with the same AST as second parameter
  # Return pair {accumulator, rest}
  #
  #   iex(1) find_ast_in_code("(1 + 2) == 3", {:+, [], [1, 2]})
  #   #=> {"(1 + 2)", "== 3"}
  #
  # Recursively take one character from code, append it to accumulator, and
  # compare accumulator's AST with reference
  #
  # Corner Case:
  #
  # * floats with trailing zeros
  #   AST for "42.00000" is 42.0
  #   when we parse "42.00000" from code we will get mathing ast for "42.0"
  #   and there wil be "0000" left in the code.
  #   Since valid Elixir code cannot start with "0" we should check the
  #   rest of the code and if it starts with "0" then we did not finish
  #   and should continue parsing
  #
  # * function without arguments
  #   For defined function with no args "foo" and "foo()" have the same AST
  #   We shoul check that the rest of the code does not start with "()"
  #   "()" without function name is invalid code in Elixir. It works but
  #   emits "invalid expression" warning
  #
  defp find_ast_in_code(code, ast, accumulator \\ "") do
    if code_match_ast?(accumulator, ast) && !(code =~ ~r/^(0|\(\))/) do
      {accumulator, code}
    else
      case String.next_grapheme(code) do
        {first_grapheme, rest} ->
          find_ast_in_code(rest, ast, accumulator <> first_grapheme)
        nil ->
          # No more characters left and still not match?
          raise AssertValue.Parser.ParseError
      end
    end
  end

  # Returns true if code's AST match the second parameter
  # Empty code does not match anything
  defp code_match_ast?("", _ast), do: false
  defp code_match_ast?(code, ast) do
    case Code.string_to_quoted(code) do
      {:ok, quoted} ->
        quoted = if is_binary(quoted) do
          String.replace(quoted, "<NOEOL>\\n", "")
        else
          quoted
        end
        ast_match?(quoted, ast)
      _ ->
        false
    end
  end

  defp ast_match?(a, b) do
    # Use === to correctly match floats
    # In Elixir 1.0 == 1 so we should continue parsing until 1.0 === 1.0
    remove_ast_meta(a) === remove_ast_meta(b)
  end

  # recursively delete meta information about line numbers and
  # hygienic counters from AST
  # iex> remove_ast_meta({:foo, [line: 10, counter: 6], []})
  # {:foo, [], []}
  defp remove_ast_meta(ast) do
    cleaner = &Keyword.drop(&1, [:line, :counter])
    Macro.prewalk(ast, &Macro.update_meta(&1, cleaner))
  end

  # Try to trim parens and whitespaces around the code recursively
  # while code's AST remains the same
  #
  # Return {trimmed_code, left_parens_acc, right_parens_acc)
  #
  #   trim_parens("  ( (foo  ) ) ")
  #   => {"foo", "  ( (", "  ) ) "}
  #
  defp trim_parens(code, left_parens_acc \\ "", right_parens_acc \\ "") do
    with [_, lp, trimmed, rp] <-
        Regex.run(~r/^(\s*\(\s*)(.*)(\s*\)\s*)$/s, code),
      {:ok, original_code_ast} <- Code.string_to_quoted(code),
      {:ok, trimmed_code_ast} <- Code.string_to_quoted(trimmed),
      true <- ast_match?(trimmed_code_ast, original_code_ast) do
        trim_parens(trimmed, left_parens_acc <> lp, rp <> right_parens_acc)
    else
      _ ->
        {code, left_parens_acc, right_parens_acc}
    end
  end

end
