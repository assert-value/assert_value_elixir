defmodule AssertValue.Server do

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    env_var_name = "ASSERT_VALUE_ACCEPT_DIFFS"
    env_settings = System.get_env(env_var_name)
    # Clear environment variable for child processes
    System.delete_env(env_var_name)
    recurring_answer = cond do
      env_settings == "y" ->
        "Y"
      env_settings == "n" ->
        "N"
      env_settings == "ask" ->
        nil
      # ASSERT_VALUE_ACCEPT_DIFFS is set to unknown value
      is_binary(env_settings) ->
        raise """
        Unknown ASSERT_VALUE_ACCEPT_DIFFS env variable value "#{env_settings}"
        Should be one of [ask,y,n]
        """
      # Check that we are running in continuous integration environment
      # TravisCI and CircleCI have this variable
      System.get_env("CI") == "true" ->
        "N"
      # Elixir sets ansi_enabled env variable on start based on
      # "/usr/bin/test -t 1 -a -t 2"
      # This checks that STDOUT and STERR are terminals. If so we
      # can prompt user for answers.
      IO.ANSI.enabled? ->
        nil
      true ->
        "N"
    end
    state = %{
      captured_ex_unit_io_pid: nil,
      file_changes: %{},
      recurring_answer: recurring_answer
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
    {answer, state} = prompt_for_action(opts, state)
    if answer in ["y", "Y"] do
      case update_expected(state.file_changes, opts[:expected_type], opts) do
        {:ok, file_changes} ->
          {:reply, {:ok, opts[:actual_value]},
            %{state | file_changes: file_changes}}
        {:error, :parse_error} ->
          {:reply, {:error, :parse_error}, state}
      end
    else
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

  def prompt_for_action(opts, state) do
    if state.recurring_answer do
      {state.recurring_answer, state}
    else
      print_diff_and_context(opts)
      get_answer(opts, state)
    end
  end

  defp print_diff_and_context(opts) do
    file =
      opts[:caller][:file]
      |> Path.relative_to(System.cwd!) # make it shorter
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

  defp get_answer(opts, state) do
    answer =
      IO.gets("Accept new value? [y,n,?] ")
      |> String.trim_trailing("\n")
    case answer do
      "?" ->
        print_help()
        get_answer(opts, state)
      "d" ->
        print_diff_and_context(opts)
        get_answer(opts, state)
      c when c in ["Y", "N"]  ->
        # Save answer in state and use it in future
        {c, %{state | recurring_answer: c}}
      _ ->
        {answer, state}
    end
  end

  defp print_help do
    """

    y - Accept new value as correct. Will update expected value. Test will pass
    n - Reject new value. Test will fail
    Y - Accept all. Will accept this and all following new values in this run
    N - Reject all. Will reject this and all following new values in this run
    d - Show diff between actual and expected values
    ? - This help
    """
    |> String.replace(~r/^/m, "    ") # Indent all lines
    |> IO.puts
  end

  # Update expected when expected is File.read!
  def update_expected(file_changes, :file, opts) do
    File.write!(opts[:expected_file], opts[:actual_value])
    {:ok, file_changes}
  end

  def update_expected(file_changes, _any, opts) do
    source_filename = opts[:caller][:file]
    original_line_number = opts[:caller][:line]
    {prefix, line, suffix} =
      split_code(file_changes, source_filename, original_line_number)
    try do
      {indentation, statement, old_expected, suffix} =
        parse_statement(line, suffix, opts)
      prefix =
        prefix <> "\n"
        <> indentation
        <> statement
        <> (if opts[:expected_action] == :create, do: " == ", else: "")
      {new_expected, new_expected_length} =
        new_expected_from_actual(opts[:actual_value], indentation)
      File.write!(source_filename, prefix <> new_expected <> suffix)
      {:ok, update_lines_count(
          file_changes,
          source_filename,
          original_line_number,
          new_expected_length - length(to_lines(old_expected))
      )}
    rescue
      AssertValue.ParseError ->
        {:error, :parse_error}
    end
  end

  # File tracking

  def current_line_number(file_changes, filename, original_line_number) do
    current_file_changes = file_changes[filename] || %{}
    cumulative_offset = Enum.reduce(current_file_changes, 0,
      fn({l, o}, total) ->
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

  defp split_code(file_changes, source_filename, original_line_number) do
    source = read_source(source_filename)
    line_number = current_line_number(
      file_changes, source_filename, original_line_number)
    {prefix, rest} = Enum.split(source, line_number - 1)
    [line | suffix] = rest
    prefix = prefix |> Enum.join("\n")
    suffix = suffix |> Enum.join("\n")
    {prefix, line, suffix}
  end

  # Inspect protocol for String has the best implementation
  # of string escaping. Use it, but remove leading and trailing ?"
  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/inspect.ex
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

  defp parse_statement(line, suffix, opts) do
    code = line <> "\n" <> suffix
    [_, indentation, statement, rest] =
      Regex.run(~r/(^\s*)(assert_value\s*)(.*)/s, code)

    {formatted_assertion, suffix} =
      parse_argument(rest, opts[:assertion_code])

    {statement, formatted_assertion, suffix} =
      trim_parentheses(statement, formatted_assertion, suffix)

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

    {indentation, statement, formatted_expected, suffix}
  end

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

  defp trim_parentheses(statement, code, suffix) do
    if code =~ ~r/^\(.*\)$/s do
      trimmed = code |> String.slice(1, String.length(code) - 2)
      if Code.string_to_quoted(trimmed) == Code.string_to_quoted(code) do
        {statement <> "(", trimmed, ")" <> suffix}
      else
        {statement, code, suffix}
      end
    else
      {statement, code, suffix}
    end
  end

  # Return new expected value and its length in lines
  defp new_expected_from_actual(actual, indentation) when is_binary(actual) do
    if length(to_lines(actual)) <= 1 do
      new_string_expected(actual)
    else
      new_heredoc_expected(actual, indentation)
    end
  end

  defp new_expected_from_actual(actual, _indentation) do
    {Macro.to_string(actual), 1}
  end

  defp new_string_expected(actual) do
    {Macro.to_string(actual), 1}
  end

  defp new_heredoc_expected(actual, indentation) do
    actual =
      actual
      |> add_noeol_if_needed
      |> to_lines
      |> Enum.map(&(indentation <> &1))
      |> Enum.map(&escape_string/1)
    new_expected = ["\"\"\""] ++ actual ++ [indentation <> "\"\"\""]
    {Enum.join(new_expected, "\n"), length(new_expected)}
  end

  # to work as a heredoc a string must end with a newline.  For
  # strings that don't we append a special token and a newline when
  # writing them to source file.  This way we can look for this
  # special token when we read it back and strip it at that time.
  defp add_noeol_if_needed(arg) do
    if arg =~ ~r/\n\Z/ do
      arg
    else
      arg <> "<NOEOL>\n"
    end
  end

end
