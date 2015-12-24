defmodule AssertValue do

  defmodule ArgumentError do
    defexception [message: ~S{Expected should be in the form of string heredoc (""") or File.read!}]
  end

  import AssertValue.FileOffsets, only: [get_line_offset: 2, set_line_offset: 3]

  defmacro assert_value({_, meta, nil} = assertion) do
    source_filename =  __CALLER__.file
    code = Macro.to_string(assertion)
    expr = Macro.escape(assertion)
    quote do
      left = unquote(assertion)
      meta = unquote(meta)
      answer = AssertValue.prompt_for_action(unquote(code), left, nil)
      case answer do
        "y" ->
          AssertValue.create_expected(unquote(source_filename), left, meta)
         _  ->
            raise ExUnit.AssertionError, [
              left: left,
              expr: unquote(expr),
              message: "AssertValue assertion failed"
            ]
      end
      left
    end
  end

  defmacro assert_value({:==, meta, [left, right]} = assertion) do
    source_filename =  __CALLER__.file
    log_filename = try_to_parse_filename(right)
    code = Macro.to_string(assertion)
    expr = Macro.escape(assertion)
    quote do
      left  = unquote(left)
      right = unquote(right)
      meta  = unquote(meta)
      log_filename = unquote(log_filename)
      # If to_sting raises Protocol.UndefinedError then either left
      # or right is wrong type and cannot be cast to string
      result = try do
        (to_string(left) == to_string(right))
      rescue
        Protocol.UndefinedError -> raise AssertValue.ArgumentError
      end
      case result do
        false ->
          answer = AssertValue.prompt_for_action(unquote(code), left, right)
          case answer do
            "y" ->
              AssertValue.update_expected(unquote(source_filename), left, right, meta, log_filename)
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

  def create_expected(source_filename, actual, [line: line_number]) do
    source = read_source(source_filename)
    line_number_with_offset = line_number + get_line_offset(source_filename, line_number)
    {prefix, rest} = Enum.split(source, line_number_with_offset - 1)
    [code_line | suffix] = rest
    [[indentation]] = Regex.scan(~r/^\s*/, code_line)
    new_expected = new_expected_from_actual(actual, indentation)
    File.open!(source_filename, [:write], fn(file) ->
      IO.puts(file, Enum.join(prefix, "\n"))
      IO.puts(file, code_line <> ~S{ == """})
      IO.puts(file, Enum.join(new_expected, "\n"))
      IO.puts(file, indentation <> ~S{"""})
      IO.write(file, Enum.join(suffix, "\n"))
    end)
    offset = length(new_expected) + 1
    set_line_offset(source_filename, line_number, offset)
  end

  # Update expected when expected is heredoc
  def update_expected(source_filename, actual, expected, [line: line_number], nil) when is_binary(expected) do
    expected = to_lines(expected)
    source = read_source(source_filename)
    line_number_with_offset = line_number + get_line_offset(source_filename, line_number)
    {prefix, rest} = Enum.split(source, line_number_with_offset)
    heredoc_close_line_number = Enum.find_index(rest, fn(s) ->
      s =~ ~r/^\s*"""/
    end)
    # If heredoc closing line is not found then right argument is a string
    unless heredoc_close_line_number, do: raise AssertValue.ArgumentError
    {_, suffix} = Enum.split(rest, heredoc_close_line_number)
    [heredoc_close_line | _] = suffix
    [[indentation]] = Regex.scan(~r/^\s*/, heredoc_close_line)
    new_expected = new_expected_from_actual(actual, indentation)
    File.open!(source_filename, [:write], fn(file) ->
      IO.puts(file, Enum.join(prefix, "\n"))
      IO.puts(file, Enum.join(new_expected, "\n"))
      IO.write(file, Enum.join(suffix, "\n"))
    end)
    offset = length(new_expected) - length(expected)
    set_line_offset(source_filename, line_number, offset)
  end

  # Update expected when expected is File.read!
  def update_expected(_, actual, _, _, filename) when is_binary(filename) do
    File.write!(filename, actual)
  end

  def update_expected(_, _, _, _, _) do
    raise AssertValue.ArgumentError
  end

  defp read_source(filename) do
    File.read!(filename) |> String.split("\n")
  end

  defp to_lines(s) do
    s
    |> to_string
    |> String.replace(~r/\n$/, "", global: false)
    |> String.split("\n")
  end

  defp try_to_parse_filename(ast) do
    try do
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} = ast
      filename
    rescue
      MatchError -> nil
    end
  end

  defp new_expected_from_actual(actual, indentation) do
    actual
    |> to_lines
    |> Enum.map(&(indentation <> &1))
  end

end
