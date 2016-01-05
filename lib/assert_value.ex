defmodule AssertValue do

  defmodule ArgumentError do
    defexception [message: ~S{Expected should be in the form of string heredoc (""") or File.read!}]
  end

  # Assertions with right argument like "assert_value actual == expected"
  defmacro assert_value({:==, _, [left, right]} = assertion) do
    [expected_type, expected_file] = case right do
      # File.read!("/path/to/file")
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} ->
        [:file, filename]
      # string, hopefully heredoc
      str when is_binary(str) -> [:source, nil]
      # any other expression, we don't support.  But we want to wait
      # till runtime to report it, otherwise it's confusing.  TODO: or
      # maybe not confusing, may want to just put here:
      # _ -> raise AssertValue.ArgumentError
      _ -> [:unsupported_value, nil]
    end

    quote do
      assertion_code = unquote(Macro.to_string(assertion))
      actual_value = unquote(left)
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
      expected_value = 
        case expected_type do
          :source -> unquote(right) |>
              String.replace(~r/\n\Z/, "", global: false)
          # TODO: should deal with a no-bang File.read instead, may
          # want to deal with different errors differently
          :file -> File.exists?(expected_file)
            && File.read!(expected_file)
            || ""
          :unsupported_value -> raise AssertValue.ArgumentError
        end

      assertion_result = (actual_value == expected_value)

      if assertion_result do
        assertion_result
      else 
        decision = AssertValue.ask_user_about_diff(
          caller: [
            file: unquote(__CALLER__.file),
            line: unquote(__CALLER__.line),
          ],
          assertion_code: assertion_code,
          actual_value: actual_value,
          expected_type: expected_type,
          expected_action: :update,
          expected_value: expected_value,
          expected_file: expected_file)

        case decision do
          [:ok, value] -> value
          [:error, error] -> raise ExUnit.AssertionError, error
        end

      end
    end
  end

  # Assertions without right argument like (assert_value "foo")
  defmacro assert_value(assertion) do
    quote do
      assertion_code = unquote(Macro.to_string(assertion))
      actual_value = unquote(assertion) # in this case
      decision = AssertValue.ask_user_about_diff(
        caller: [
          file: unquote(__CALLER__.file),
          line: unquote(__CALLER__.line),
        ],
        actual_value: actual_value,
        assertion_code: assertion_code,
        expected_type: :source,
        expected_action: :create,
        expected_value: nil)

      case decision do
        [:ok, value] -> value
        [:error, error] -> raise ExUnit.AssertionError, error
      end
    end
  end

  def ask_user_about_diff(opts) do
    answer = prompt_for_action(opts[:assertion_code],
                               opts[:actual_value],
                               opts[:expected_value])
    
    case answer do
      "y" ->
        case opts[:expected_action] do
          :update ->
            update_expected(opts[:expected_type],
                            opts[:caller][:file],
                            opts[:caller][:line],
                            opts[:actual_value],
                            opts[:expected_value],
                            opts[:expected_file]) # TODO: expected_filename
          :create ->
            create_expected(opts[:caller][:file],
                            opts[:caller][:line],
                            opts[:actual_value])
        end
        [:ok, opts[:actual_value]] # actual has now become expected
      _  ->
        # we pass exception up to the caller and throw it there to
        # avoid having this function be extra frame in exception's
        # call stack
        [:error,
         [left: opts[:actual_value],
          # TODO: maybe we should only add right field on update.  In
          # that case it would probably make sense to construct the
          # whole exception in the caller
          right: opts[:expected_value],
          expr: opts[:assertion_code],
          message: "AssertValue assertion failed"]]
    end
  end
  
  def prompt_for_action(code, left, right) do
    # HACK: sleep to let ExUnit event handler finish output. Otherwise
    # ExUnit output will interfere with our output. Since this only
    # happens when doing the interactive prompt/action, sleeping some
    # is not a big deal
    :timer.sleep(30)
    IO.puts "\n<Failed Assertion Message>"
    IO.puts "    #{code}\n"
    IO.puts AssertValue.Diff.diff(right, left)
    IO.gets("Accept new value [y/n]? ")
    |> String.rstrip(?\n)
  end

  def create_expected(source_filename, original_line_number, actual) do
    source = read_source(source_filename)
    line_number =
      AssertValue.FileTracker.current_line_number(
        source_filename, original_line_number)
    {prefix, rest} = Enum.split(source, line_number - 1)
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
    AssertValue.FileTracker.update_lines_count(
      source_filename, original_line_number, length(new_expected) + 1)
  end

  # Update expected when expected is heredoc
  def update_expected(:source, source_filename, original_line_number,
                      actual, expected, _) do
    expected = to_lines(expected)
    source = read_source(source_filename)
    line_number =
      AssertValue.FileTracker.current_line_number(
        source_filename, original_line_number)
    {prefix, rest} = Enum.split(source, line_number)
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
    AssertValue.FileTracker.update_lines_count(
      source_filename, original_line_number, length(new_expected) - length(expected))
  end

  # Update expected when expected is File.read!
  def update_expected(:file, _, _, actual, _, expected_filename) do
    File.write!(expected_filename, actual)
  end

  defp read_source(filename) do
    File.read!(filename) |> String.split("\n")
  end

  defp to_lines(arg) do
    arg
    |> String.split("\n")
  end

  defp new_expected_from_actual(actual, indentation) do
    actual
    |> to_lines
    |> Enum.map(&(indentation <> &1))
    |> Enum.map(&escape_string/1)
  end

  # Inspect protocol for String has the best implementation
  # of string escaping. Use it, but remove leading and trailing ?"
  # See https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/inspect.ex
  defp escape_string(s) do
    s
    |> inspect
    |> String.replace(~r/(\A")|("\Z)/, "")
  end

end
