defmodule AssertValue.Server do

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    state = %{
      captured_ex_unit_io_pid: nil,
      tests_waiting_to_ask: [],
      tests_waiting_to_finish: [],
      file_changes: %{}
    }
    {:ok, state}
  end

  def handle_cast({:set_captured_ex_unit_io_pid, pid}, state) do
    {:noreply, %{state | captured_ex_unit_io_pid: pid}}
  end

  def handle_cast({:test_finished, filename_and_test}, state) do
    tests_left_to_finish =
      state.tests_waiting_to_finish
      |> Enum.filter(&(&1 != filename_and_test))

    if (tests_left_to_finish == [] && state.tests_waiting_to_ask != []) do
      [{reply_to, opts} | tests_left_to_ask] = state.tests_waiting_to_ask
      contents = StringIO.flush(state.captured_ex_unit_io_pid)
      if contents != "", do: IO.write contents
      filename_and_test = filename_and_test(opts)
      tests_waiting_to_finish = tests_left_to_finish ++ [filename_and_test]
      {reply, state} = do_ask(opts, state)
      GenServer.reply(reply_to, reply)
      {:noreply, %{state |
        tests_waiting_to_ask: tests_left_to_ask,
        tests_waiting_to_finish: tests_waiting_to_finish}}
    else
      {:noreply, %{state | tests_waiting_to_finish: tests_left_to_finish}}
    end
  end

  def handle_cast({:flush_ex_unit_io}, state) do
    contents = StringIO.flush(state.captured_ex_unit_io_pid)
    if contents != "", do: IO.write contents
    {:noreply, state}
  end

  # This a synchronous call
  # No other AssertValue diffs will be shown until user give answer
  def handle_call({:ask_user_about_diff, opts}, from, state) do
    filename_and_test = filename_and_test(opts)
    # Check that there are no tests to finish output or
    # this is the same test we asked previous time. Then
    # we can ask again becase this will be the same output.
    other_tests_left_to_finish =
      state.tests_waiting_to_finish
      |> Enum.filter(&(&1 != filename_and_test))

    if other_tests_left_to_finish == [] do
      tests_waiting_to_finish = other_tests_left_to_finish ++ [filename_and_test]
      state = %{state | tests_waiting_to_finish: tests_waiting_to_finish}
      {reply, state} = do_ask(opts, state)
      {:reply, reply, state}
    else
      {:noreply, %{state |
        tests_waiting_to_ask: state.tests_waiting_to_ask ++ [{from, opts}]}}
    end
  end

  defp do_ask(opts, state) do
    answer = prompt_for_action(
      opts[:caller][:file],
      opts[:caller][:line],
      opts[:caller][:function],
      opts[:assertion_code],
      opts[:actual_value],
      opts[:expected_value]
    )
    case answer do
      "y" ->
        result = case opts[:expected_action] do
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
        case result do
          {:ok, file_changes} ->
            {{:ok, opts[:actual_value]}, %{state | file_changes: file_changes}}
          {:error, :unsupported_value} ->
            {{:error, :unsupported_value}, state}
        end
      _  ->
        # Fail test. Pass exception up to the caller and throw it there
        {{:error, :ex_unit_assertion_error, [left: opts[:actual_value],
            right: opts[:expected_value],
            expr: opts[:assertion_code],
            message: "AssertValue assertion failed"]},
        state}
    end
  end

  def set_captured_ex_unit_io_pid(pid) do
    GenServer.cast __MODULE__, {:set_captured_ex_unit_io_pid, pid}
  end

  def test_finished(filename_and_test) do
    GenServer.cast __MODULE__, {:test_finished, filename_and_test}
  end

  def flush_ex_unit_io do
    GenServer.cast __MODULE__, {:flush_ex_unit_io}
  end

  def ask_user_about_diff(opts) do
    # Wait for user's input forever
    GenServer.call __MODULE__, {:ask_user_about_diff, opts}, :infinity
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
    {:ok, update_lines_count(file_changes, source_filename,
      original_line_number, length(new_expected) + 1)}
  end

  # Update expected when expected is heredoc
  # return {:error, :unsupported_value} if not
  def update_expected(file_changes, :source, source_filename, original_line_number,
                      actual, expected, _) do
    expected = to_lines(expected)
    source = read_source(source_filename)
    line_number = current_line_number(file_changes, source_filename, original_line_number)
    line = Enum.at(source, line_number - 1)
    heredoc_open = Regex.named_captures(
      ~r/assert_value.*==\s*(?<heredoc>\"{3}).*/, line)["heredoc"]
    if heredoc_open do
      {prefix, rest} = Enum.split(source, line_number)
      heredoc_close_line_number = Enum.find_index(rest, fn(s) ->
        s =~ ~r/^\s*#{Regex.escape(heredoc_open)}/
      end)
      {_, suffix} = Enum.split(rest, heredoc_close_line_number)
      [heredoc_close_line | _] = suffix
      [[indentation]] = Regex.scan(~r/^\s*/, heredoc_close_line)
      new_expected = new_expected_from_actual(actual, indentation)
      File.open!(source_filename, [:write], fn(file) ->
        IO.puts(file, Enum.join(prefix, "\n"))
        IO.puts(file, Enum.join(new_expected, "\n"))
        IO.write(file, Enum.join(suffix, "\n"))
      end)
      {:ok, update_lines_count(file_changes, source_filename,
        original_line_number, length(new_expected) - length(expected))}
    # If heredoc closing line is not found then right argument is a string
    else
      {:error, :unsupported_value}
    end
  end

  # Update expected when expected is File.read!
  def update_expected(file_changes, :file, _, _, actual, _, expected_filename) do
    File.write!(expected_filename, actual)
    {:ok, file_changes}
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

  defp filename_and_test(opts) do
    test_filename = opts[:caller][:file]
    {test_name, _arity} = opts[:caller][:function]
    {test_filename, test_name}
  end

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
