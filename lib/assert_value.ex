defmodule AssertValue do

  defmacro assert_value({:==, meta, [left, right]} = assertion) do
    source_filename =  __CALLER__.file
    log_filename = try_to_parse_filename(right)
    code = Macro.to_string(assertion)
    expr = Macro.escape(assertion)
    quote do
      left  = unquote(left)
      right = unquote(right)
      meta  = unquote(meta)
      result = (to_string(left) == to_string(right))
      case result do
        false ->
          answer = AssertValue.prompt_for_action(unquote(code), left, right)
          case answer do
            "y" ->
              AssertValue.update_expected(unquote(source_filename), left, right, meta, unquote(log_filename))
             _  ->
              raise ExUnit.AssertionError, [
                left: left,
                right: right,
                expr: unquote(expr),
                message: "AssertValue assertion failed"
              ]
          end
        _ -> result
      end
    end
  end

  defp try_to_parse_filename(ast) do
    try do
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} = ast
      filename
    rescue
      MatchError -> nil
    end
  end

  # Update expected when expected is heredoc
  def update_expected(source_filename, actual, expected, [line: line_number], nil) when is_list(expected) do
    source =
      File.read!(source_filename)
      |> String.split("\n")
    {prefix, rest} = Enum.split(source, line_number)
    heredoc_close_line_number = Enum.find_index(rest, fn(s) ->
      s =~ ~r/^\s*'''/
    end)
    {_, suffix} = Enum.split(rest, heredoc_close_line_number)
    [heredoc_close_line | _] = suffix
    [[indentation]] = Regex.scan(~r/^\s*/, heredoc_close_line)
    new_expected =
      to_string(actual)
      |> String.rstrip(?\n)
      |> String.split("\n")
      |> Enum.map(&(indentation <> &1))
      |> Enum.join("\n")
    File.open!(source_filename, [:write], fn(file) ->
      IO.puts(file, Enum.join(prefix, "\n"))
      IO.puts(file, new_expected)
      IO.write(file, Enum.join(suffix, "\n"))
    end)
  end

  # Update expected when expected is File.read!
  def update_expected(_, actual, _, _, filename) when is_binary(filename) do
    File.write!(filename, actual)
  end

  def prompt_for_action(code, left, right) do
    # HACK: Let ExUnit event handler to finish output
    # Otherwise ExUnit output will interfere with our output
    # Since this is interactive part 10 millisecond is not a big deal
    :timer.sleep(10)
    IO.puts "\n<Failed Assertion Message>"
    IO.puts "    #{code}\n"
    IO.puts AssertValue.Diff.diff(right, left)
    IO.gets("Accept new value [y/n]? ")
    |> String.rstrip(?\n)
  end

end
