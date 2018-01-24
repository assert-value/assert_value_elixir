defmodule AssertValue.Server do

  use GenServer
  import AssertValue.StringTools

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
      env_settings == "reformat" ->
        "R"
      env_settings == "ask" ->
        nil
      # ASSERT_VALUE_ACCEPT_DIFFS is set to unknown value
      is_binary(env_settings) ->
        raise """
        Unknown ASSERT_VALUE_ACCEPT_DIFFS env variable value "#{env_settings}"
        Should be one of [y,n,ask,reformat]
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

  def handle_call({:reformat_expected?}, _from, state) do
    {:reply, state.recurring_answer == "R", state}
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
    if answer in ["y", "Y", "R"] do
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
          expr: Macro.to_string(opts[:assertion_ast]),
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

  def reformat_expected? do
    GenServer.call __MODULE__, {:reformat_expected?}, :infinity
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
    code = opts[:assertion_ast] |> Macro.to_string |> smart_truncate(40)
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
    current_line_number = current_line_number(
      file_changes,
      opts[:caller][:file],
      opts[:caller][:line]
    )
    case AssertValue.Parser.parse_expected(
      opts[:caller][:file],
      current_line_number,
      opts[:assertion_ast],
      opts[:actual_ast],
      opts[:expected_ast]
    ) do
      {prefix, old_expected, suffix, indentation} ->
        new_expected = AssertValue.Formatter.new_expected_from_actual_value(
          opts[:actual_value], indentation)
        File.write!(opts[:caller][:file], prefix <> new_expected <> suffix)
        {:ok, update_lines_count(
          file_changes,
          opts[:caller][:file],
          opts[:caller][:line],
          length(to_lines(new_expected)) - length(to_lines(old_expected))
        )}
      {:error, :parse_error} ->
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

end
