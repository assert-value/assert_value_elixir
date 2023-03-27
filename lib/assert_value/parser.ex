defmodule AssertValue.Parser do
  # This is internal parser error
  # In theory we parse any valid Elixir code and should not face it
  defmodule ParseError do
    defexception message: "Unable to parse assert_value arguments"
  end

  # Parse file with test code and returns {:ok, parsed} on success
  # where parsed is a map with keys:
  #
  # :prefix - code before line with assert_value
  # :assert_value - whole assert_value call with all arguments as it is
  #   formatted in the code
  # :indentation - spaces from the beginning of the line to "assert_value"
  # :assert_value_prefix - everything in assert_value call before expected
  #   as it is formatted in the code (including ==)
  # :expected - expected as it is formatted in the code (including quotes)
  # :assert_value_suffix - everything left in assert_value after expected
  #   (closing parens, spaces, etc)
  # :suffix - code after last line of assert_value call (with all arguments)
  #
  # Example:
  #
  # defmodule AssertValue.DevTest do ----+
  #   use ExUnit.Case                    |
  #                                      | :prefix
  #   import AssertValue                 |
  #                                      |
  #   test "list" do                 ----+
  #      assert_value "foo" == "bar"       :assert_value
  #   end                            ----+
  #                                      | :suffix
  # end                              ----+
  #
  # +---+-- :indentation       +---+------ :expected
  # |   |                      |   |
  #      assert_value "foo" == "bar"  \n
  #      |                    |     |  |
  #      |                    |     +--+-- :assert_value_suffix
  #      |                    |
  #      +--------------------+----------- :assert_value_prefix
  #
  # Returns {:error, :parse_error} on failure
  #
  def parse_assert_value(
        filename,
        line_num,
        assertion_ast,
        actual_ast,
        expected_ast
      ) do
    {prefix, suffix} =
      File.read!(filename)
      |> String.split("\n")
      |> Enum.split(line_num - 1)

    prefix = prefix |> Enum.join("\n")
    suffix = suffix |> Enum.join("\n")

    [_, indentation, assert_value, rest] =
      Regex.run(~r/(^\s*)(assert_value\s*)(.*)/s, suffix)

    prefix = prefix <> "\n"
    assert_value_prefix = indentation <> assert_value
    assert_value_suffix = ""

    # We enclose parsing in try/rescue because parser code is executed
    # inside genserver. Exceptions raised in genserver produce unreadable
    # Erlang error messages so it is better to pass theese exceptions outside
    # genserver and reraise them to show readable Elixir error messages
    try do
      {assertion, suffix} = find_ast_in_code(rest, assertion_ast)
      assert_value = assert_value_prefix <> assertion
      {assertion, left_parens, right_parens} = trim_parens(assertion)
      assert_value_prefix = assert_value_prefix <> left_parens
      assert_value_suffix = right_parens <> assert_value_suffix

      {assert_value_prefix, rest} =
        if actual_ast == :_not_present_ do
          {assert_value_prefix <> assertion, ""}
        else
          {actual, rest} = find_ast_in_code(assertion, actual_ast)
          {assert_value_prefix <> actual, rest}
        end

      {assert_value_prefix, expected, assert_value_suffix} =
        if expected_ast == :_not_present_ do
          {
            assert_value_prefix <> " == ",
            "",
            assert_value_suffix
          }
        else
          [_, operator, _, rest] = Regex.run(~r/((\)|\s)*==\s*)(.*)/s, rest)
          {expected, rest} = find_ast_in_code(rest, expected_ast)

          {
            assert_value_prefix <> operator,
            expected,
            rest <> assert_value_suffix
          }
        end

      {:ok,
       %{
         prefix: prefix,
         suffix: suffix,
         assert_value: assert_value,
         assert_value_prefix: assert_value_prefix,
         assert_value_suffix: assert_value_suffix,
         expected: expected,
         indentation: indentation
       }}
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
        quoted =
          if is_binary(quoted) do
            String.replace(quoted, "<NOEOL>\\n", "")
          else
            quoted
          end

        ast_match?(quoted, ast)

      _ ->
        false
    end

    # Elixir 1.13 raises MatchError on some escape characters
    # https://github.com/elixir-lang/elixir/issues/11813
  rescue
    _ -> false
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
