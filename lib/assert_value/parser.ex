defmodule AssertValue.Parser do

  def parse_expected(opts, current_line_number) do
    source = read_source(opts[:caller][:file])
    {prefix, suffix} = Enum.split(source, current_line_number - 1)
    prefix = prefix |> Enum.join("\n")
    suffix = suffix |> Enum.join("\n")

    [_, indentation, statement, rest] =
      Regex.run(~r/(^\s*)(assert_value\s*)(.*)/s, suffix)

    try do
      {formatted_assertion, suffix} =
        parse_argument(rest, opts[:assertion_code])

      {statement, formatted_assertion, suffix} =
        trim_parens(statement, formatted_assertion, suffix)

      {statement, rest, suffix} =
        if opts[:actual_code] do
          {formatted_actual, rest} =
            parse_argument(formatted_assertion, opts[:actual_code])
          statement = statement <> formatted_actual
          {statement, rest, suffix}
        else
          {statement <> formatted_assertion, "", suffix}
        end

      {statement, formatted_expected, suffix} =
        if opts[:expected_code] do
          [_, operator, _, rest] =
            Regex.run(~r/((\)|\s)+==\s*)(.*)/s, rest)
          statement = statement <> operator
          {formatted_expected, rest} =
            parse_argument(rest, opts[:expected_code])
          {statement, formatted_expected, rest <> suffix}
        else
          {statement, "", suffix}
        end

      prefix =
        prefix <> "\n"
        <> indentation
        <> statement
        <> (if opts[:expected_action] == :create, do: " == ", else: "")

      {prefix, formatted_expected, suffix, indentation}
    rescue
      AssertValue.ParseError ->
        {:error, :parse_error}
    end
  end

  # Private

  defp parse_argument(code, formatted_value, parsed_value \\ "") do
    {_, value} = Code.string_to_quoted(parsed_value)
    value = if is_binary(value) && String.match?(value, ~r/<NOEOL>/) do
      # In quoted code newlines are quoted
      String.replace(value, "<NOEOL>\\n", "")
    else
      value
    end
    # There may be differences between AST evaluated from string and the one
    # from compiler for complex values because of line numbers, etc...
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
    if Macro.to_string(value) == formatted_value do
      {parsed_value, code}
    else
      case String.next_grapheme(code) do
        {char, rest} ->
          parse_argument(rest, formatted_value, parsed_value <> char)
        nil ->
          raise AssertValue.ParseError
      end
    end
  end

  # Try to trim parens and whitespace recursively
  # "  ( (foo  ) ) " => "foo"
  defp trim_parens(statement, code, suffix) do
    regex = ~r/^(\s*\(\s*)(.*)(\s*\)\s*)$/s
    if code =~ regex do
      [_, lp, trimmed, rp] = Regex.run(regex, code)
      # We need to compare code without meta information
      # See comment in a parse_argument above
      if Macro.to_string(Code.string_to_quoted(trimmed)) ==
          Macro.to_string(Code.string_to_quoted(code)) do
        trim_parens(statement <> lp, trimmed, rp <> suffix)
      else
        {statement, code, suffix}
      end
    else
      {statement, code, suffix}
    end
  end

  defp read_source(filename) do
    File.read!(filename) |> String.split("\n")
  end

end
