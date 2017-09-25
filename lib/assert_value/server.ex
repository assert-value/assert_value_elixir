defmodule AssertValue.Server do

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    state = %{
      captured_ex_unit_io_pid: nil,
      file_changes: %{}
    }
    {:ok, state}
  end

  def handle_cast({:set_captured_ex_unit_io_pid, pid}, state) do
    {:noreply, %{state | captured_ex_unit_io_pid: pid}}
  end

  def handle_cast({:flush_ex_unit_io}, state) do
    contents = StringIO.flush(state.captured_ex_unit_io_pid)
    if contents != "", do: IO.write contents
    {:noreply, state}
  end

  # This a synchronous call
  # No other AssertValue diffs will be shown until user give answer
  def handle_call({:ask_user_about_diff, opts}, _from, state) do
    # Hack: We try to wait until previous test asking about diff (and fail) will
    # output test results. Otherwise user will get previous failed test result
    # message right after the answer for current test.
    # TODO: Refactor to messaging
    Process.sleep(30)
    contents = StringIO.flush(state.captured_ex_unit_io_pid)
    if contents != "", do: IO.write contents
    answer = prompt_for_action(
      opts[:caller][:file],
      opts[:caller][:line],
      opts[:caller][:function],
      opts[:assertion_code],
      opts[:actual_value],
      opts[:expected_value]
    )
    file_changes = case answer do
      "y" ->
        case opts[:expected_action] do
          :update ->
            update_expected(
              state.file_changes,
              opts[:expected_type],
              opts[:caller][:file],
              opts[:caller][:line],
              opts[:actual_value],
              opts[:expected_value],
              opts[:expected_file] # TODO: expected_filename
            )
          :create ->
            create_expected(
              state.file_changes,
              opts[:caller][:file],
              opts[:caller][:line],
              opts[:actual_value]
            )
        end
      _  ->
        state.file_changes
    end
    {:reply, answer, %{state | file_changes: file_changes}}
  end

  def set_captured_ex_unit_io_pid(pid) do
    GenServer.cast __MODULE__, {:set_captured_ex_unit_io_pid, pid}
  end

  def flush_ex_unit_io do
    GenServer.cast __MODULE__, {:flush_ex_unit_io}
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

  def create_expected(file_changes, source_filename, original_line_number, actual) do
    source = read_source(source_filename)
    line_number = current_line_number(file_changes, source_filename, original_line_number)
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
    update_lines_count(file_changes, source_filename, original_line_number, length(new_expected) + 1)
  end

  # Update expected when expected is heredoc
  def update_expected(file_changes, :source, source_filename, original_line_number,
                      actual, expected, _) do
    expected = to_lines(expected)
    source = read_source(source_filename)
    line_number = current_line_number(file_changes, source_filename, original_line_number)
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
    update_lines_count(file_changes, source_filename, original_line_number, length(new_expected) - length(expected))
  end

  # Update expected when expected is File.read!
  def update_expected(file_changes, :file, _, _, actual, _, expected_filename) do
    File.write!(expected_filename, actual)
    file_changes
  end

  # File tracking

  def current_line_number(file_changes, filename, original_line_number) do
    current_file_changes = file_changes[filename] || %{}
    cumulative_offset = Enum.reduce(current_file_changes, 0, fn({l,o}, total) ->
      if original_line_number > l, do: total + o, else: total
    end)
    original_line_number + cumulative_offset
  end

  def update_lines_count(file_changes, filename, original_line_number, diff) do
    current_file_changes =
      (file_changes[filename] || %{})
      |> Map.put(original_line_number, diff)
    Map.put(file_changes, filename, current_file_changes)
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
