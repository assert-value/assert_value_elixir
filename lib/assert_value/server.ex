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
    answer = prompt_for_action(opts)
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
            {:reply, {:ok, opts[:actual_value]}, %{state | file_changes: file_changes}}
          {:error, :unsupported_value} ->
            {:reply, {:error, :unsupported_value}, state}
        end
      _  ->
        # Fail test. Pass exception up to the caller and throw it there
        {:reply,  {:error, :ex_unit_assertion_error, [left: opts[:actual_value],
            right: opts[:expected_value],
            expr: opts[:assertion_code],
            message: "AssertValue assertion failed"]},
        state}
    end
  end

  def set_captured_ex_unit_io_pid(pid) do
    GenServer.cast __MODULE__, {:set_captured_ex_unit_io_pid, pid}
  end

  def flush_ex_unit_io do
    GenServer.cast __MODULE__, {:flush_ex_unit_io}
  end

  def ask_user_about_diff(opts) do
    # Wait for user's input forever
    GenServer.call __MODULE__, {:ask_user_about_diff, opts}, :infinity
  end

  def prompt_for_action(opts) do
    print_diff_and_context(opts)
    get_answer(opts)
  end

  defp print_diff_and_context(opts) do
    file = opts[:caller][:file] |> Path.relative_to(System.cwd!) # make it shorter
    line = opts[:caller][:line]
    # the prompt we print here should
    # * let user easily identify which assert failed
    # * work with editors's automatic go-to-error-line file:line:
    #   format handling
    # * not be unreasonably long, so the user sees it on the screen
    #   grouped with the diff
    {function, _} = opts[:caller][:function]
    code = opts[:assertion_code] |> smart_truncate_string(40)
    diff_context = "#{file}:#{line}:\"#{Atom.to_string function}\" assert_value #{code} failed"
    diff = AssertValue.Diff.diff(opts[:expected_value], opts[:actual_value])
    diff_lines_count = String.split(diff, "\n") |> Enum.count()
    IO.puts "\n" <> diff_context <> "\n"
    IO.puts diff
    # If diff is too long diff context does not fit to screen
    # we need to repeat it
    if diff_lines_count > 37, do: IO.puts diff_context
  end

  defp get_answer(opts) do
    answer =
      IO.gets("Accept new value [y/n/d/?]? ")
      |> String.trim_trailing("\n")
    case answer do
      "?" ->
        print_help()
        get_answer(opts)
      "d" ->
        print_diff_and_context(opts)
        get_answer(opts)
      _ ->
        answer
    end
  end

  defp print_help do
    """

    y - Accept and overwrite new expected value in test code. Test will pass
    n - Do not accept new expected value. Test will fail
    d - Show diff between actual and expected value
    ? - This help
    """
    |> String.replace(~r/^/m, "    ") # Indent all lines
    |> IO.puts
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
    actual = if actual =~ ~r/\n\Z/ do
      actual
    else
      actual <> "<NOEOL>\n"
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

  defp smart_truncate_string(s, length) when is_binary(s) and length > 0 do
    if String.length(s) <= length do
      s
    else
      s
      |> String.slice(0..length - 1)
      |> Kernel.<>("...")
    end
  end

end
