defmodule AssertValue.Parser do

  # This is internal parser error
  # In theory we parse any valid Elixir code and should not face it
  defmodule ParseError do
    defexception [message: "Unable to parse assert_value arguments"]
  end

  # Split file contents (code) to three parts:
  #   * everything before assert_value_code (prefix)
  #   * assert_value code
  #   * everything after assert_value_code (suffix)
  #
  #   code == prefix <> assert_value <> suffix
  #
  def parse_assert_value(filename, line_num, assertion_ast) do
    {prefix, suffix} =
      File.read!(filename)
      |> String.split("\n")
      |> Enum.split(line_num - 1)

    [_, indentation] = Regex.run(~r/(^\s*)assert_value/s, Enum.at(suffix, 0))

    # We enclose parsing in try/rescue because parser code is executed
    # inside genserver. Exceptions raised in genserver produce unreadable
    # Erlang error messages so it is better to pass theese exceptions outside
    # genserver and reraise them to show readable Elixir error messages
    try do
      assert_value_ast = {:assert_value, [], [assertion_ast]}
      {assert_value, suffix} = find_ast_in_code(suffix, assert_value_ast)

      prefix = prefix |> Enum.join("\n")
      assert_value = assert_value |> Enum.join("\n")
      suffix = suffix |> Enum.join("\n")

      {prefix, assert_value, suffix, indentation}
    rescue
      AssertValue.Parser.ParseError ->
        {:error, :parse_error}
    end
  end

  # Private

  # Finds lines in code with the same AST as second parameter
  # Return pair {accumulator, rest}
  defp find_ast_in_code(lines_left, ast, lines_so_far \\ []) do
    if code_match_ast?(Enum.join(lines_so_far, "\n"), ast) do
      {lines_so_far, lines_left}
    else
      if lines_left == [] do
          # No more lines and still not match?
          raise AssertValue.Parser.ParseError
      else
        [l | rest] = lines_left
        find_ast_in_code(rest, ast, lines_so_far ++ [l])
      end
    end
  end

  # Returns true if code's AST match the second parameter
  # Empty code does not match anything
  defp code_match_ast?("", _ast), do: false
  defp code_match_ast?(code, ast) do
    case Code.string_to_quoted(code) do
      {:ok, quoted} ->
        remove_ast_meta(quoted) === remove_ast_meta(ast)
      _ ->
        false
    end
  end

  # recursively delete meta information about line numbers and
  # hygienic counters from AST
  # iex> remove_ast_meta({:foo, [line: 10, counter: 6], []})
  # {:foo, [], []}
  def remove_ast_meta(ast) do
    cleaner = &Keyword.drop(&1, [:line, :counter, :ambiguous_op])
    Macro.prewalk(ast, &Macro.update_meta(&1, cleaner))
  end

end
