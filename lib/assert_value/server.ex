defmodule AssertValue.Server do

  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def format_status(_reason, [ _pdict, state ]) do
    [data: [{'State', "Saved file offsets: #{inspect state}"}]]
  end

  # This a synchronous call
  # No other AssertValue diffs will be shown until user give answer
  def handle_call({:ask_user_about_diff, opts}, _from, data) do
    answer = __MODULE__.prompt_for_action(
      opts[:caller][:file],
      opts[:caller][:line],
      opts[:caller][:function],
      opts[:assertion_code],
      opts[:actual_value],
      opts[:expected_value]
    )
    data = case answer do
      "y" ->
        case opts[:expected_action] do
          :update ->
            __MODULE__.update_expected(
              data,
              opts[:expected_type],
              opts[:caller][:file],
              opts[:caller][:line],
              opts[:actual_value],
              opts[:expected_value],
              opts[:expected_file] # TODO: expected_filename
            )
          :create ->
            __MODULE__.create_expected(
              data,
              opts[:caller][:file],
              opts[:caller][:line],
              opts[:actual_value]
            )
        end
      _  ->
        data
    end
    {:reply, answer, data}
  end

  def ask_user_about_diff(opts) do
    # Wait for user's input forever
    answer = GenServer.call __MODULE__, {:ask_user_about_diff, opts}, :infinity
    case answer do
      "y" ->
        {:ok, opts[:actual_value]} # actual has now become expected
      _  ->
        # we pass exception up to the caller and throw it there
        {:error,
         [left: opts[:actual_value],
          right: opts[:expected_value],
          expr: opts[:assertion_code],
          message: "AssertValue assertion failed"]}
    end
  end

  def prompt_for_action(file, line, function, code, left, right) do
    file = Path.relative_to(file, System.cwd!) # make it shorter
    # the prompt we print here should
    # * let user easily identify which assert failed
    # * work with editors's automatic go-to-error-line file:line:
    #   format handling
    # * not be unreasonably long, so the user sees it on the screen
    #   grouped with the diff
    {function, _} = function
    IO.puts "\n#{file}:#{line}:\"#{Atom.to_string function}\" assert_value #{code} failed. Diff:"
    IO.write AssertValue.Diff.diff(right, left)
    IO.gets("Accept new value [y/n]? ")
    |> String.rstrip(?\n)
  end

  def create_expected(data, source_filename, original_line_number, actual) do
    source = read_source(source_filename)
    line_number = current_line_number(data, source_filename, original_line_number)
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
    update_lines_count(data, source_filename, original_line_number, length(new_expected) + 1)
  end

  # Update expected when expected is heredoc
  def update_expected(data, :source, source_filename, original_line_number,
                      actual, expected, _) do
    expected = to_lines(expected)
    source = read_source(source_filename)
    line_number = current_line_number(data, source_filename, original_line_number)
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
    update_lines_count(data, source_filename, original_line_number, length(new_expected) - length(expected))
  end

  # Update expected when expected is File.read!
  def update_expected(data, :file, _, _, actual, _, expected_filename) do
    File.write!(expected_filename, actual)
    data
  end

  # File tracking

  def current_line_number(data, filename, original_line_number) do
    file_changes = data[filename] || %{}
    cumulative_offset = Enum.reduce(file_changes, 0, fn({l,o}, total) ->
      if original_line_number > l, do: total + o, else: total
    end)
    original_line_number + cumulative_offset
  end

  def update_lines_count(data, filename, original_line_number, diff) do
    file_changes =
      (data[filename] || %{})
      |> Map.put(original_line_number, diff)
    Map.put(data, filename, file_changes)
  end

  # Private

  defp read_source(filename) do
    File.read!(filename) |> String.split("\n")
  end

  defp to_lines(arg) do
    arg
    # remove trailing newline otherwise String.split will give us an
    # empty line at the end
    |> String.replace(~r/\n\Z/, "", global: false)
    |> String.split("\n")
  end

  defp new_expected_from_actual(actual, indentation) do
    # to work as a heredoc a string must end with a newline.  For
    # strings that don't we append a special token and a newline when
    # writing them to source file.  This way we can look for this
    # special token when we read it back and strip it at that time.
    actual = unless actual =~ ~r/\n\Z/ do
      actual <> "<NOEOL>\n"
    else
      actual
    end

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
