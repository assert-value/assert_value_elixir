defmodule AssertValue.Server do
  use GenServer
  import AssertValue.StringTools

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    env_var_name = "ASSERT_VALUE_ACCEPT_DIFFS"
    env_settings = System.get_env(env_var_name)
    # Clear environment variable for child processes
    System.delete_env(env_var_name)

    recurring_answer =
      cond do
        env_settings == "y" ->
          "Y"

        env_settings == "n" ->
          "N"

        env_settings == "reformat" ->
          # Store this recurring_answer as atom to make it impossible
          # for user to enter it on asking about diff
          :reformat

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
        IO.ANSI.enabled?() ->
          nil

        true ->
          "N"
      end

    state = %{
      original_group_leader: nil,
      file_changes: %{},
      recurring_answer: recurring_answer
    }

    {:ok, state}
  end

  # makes this server IO device
  def handle_info({:io_request, from, ref, request}, state) do
    case io_handle(request, state) do
      {:ok, reply, new_state} ->
        send(from, {:io_reply, ref, reply})
        {:noreply, new_state}

      {:error, reason, new_state} ->
        send(from, {:io_reply, ref, {:error, reason}})
        {:noreply, new_state}
    end
  end

  def handle_cast({:set_original_group_leader, gl}, state) do
    {:noreply, %{state | original_group_leader: gl}}
  end

  def handle_call({:get_original_group_leader}, _from, state) do
    {:reply, state.original_group_leader, state}
  end

  def handle_call({:get_pid}, _from, state) do
    {:reply, self(), state}
  end

  def handle_call({:reformat_expected?}, _from, state) do
    {:reply, state.recurring_answer == :reformat, state}
  end

  def handle_call({:ask_user_about_diff, opts}, _from, state) do
    case prepare_formatted_diff_and_new_code(opts, state) do
      {:ok, prepared} ->
        {answer, state} = prompt_for_action(prepared.diff, opts, state)

        if answer in ["y", "Y", :reformat] do
          file_changes =
            if opts[:expected_type] == :file do
              File.write!(opts[:expected_file], opts[:actual_value])
              state.file_changes
            else
              File.write!(opts[:caller][:file], prepared.new_file_content)

              update_line_numbers(
                state.file_changes,
                opts[:caller][:file],
                opts[:caller][:line],
                prepared.old_assert_value,
                prepared.new_assert_value
              )
            end

          {:reply, :ok, %{state | file_changes: file_changes}}
        else
          # Fail test. Pass exception up to the caller and throw it there
          {:reply,
           {:error, :ex_unit_assertion_error,
            [
              left: opts[:actual_value],
              right: opts[:expected_value],
              expr: Macro.to_string(opts[:assertion_ast]),
              message: "AssertValue assertion failed"
            ]}, state}
        end

      {:error, :parse_error} ->
        {:reply, {:error, :parse_error}, state}
    end
  end

  # All calls get :infinity timeout because GenServer may wait for user input

  def set_original_group_leader(gl) do
    GenServer.cast(__MODULE__, {:set_original_group_leader, gl})
  end

  def get_original_group_leader do
    GenServer.call(__MODULE__, {:get_original_group_leader}, :infinity)
  end

  def get_pid do
    GenServer.call(__MODULE__, {:get_pid}, :infinity)
  end

  def reformat_expected? do
    GenServer.call(__MODULE__, {:reformat_expected?}, :infinity)
  end

  def ask_user_about_diff(opts) do
    GenServer.call(__MODULE__, {:ask_user_about_diff, opts}, :infinity)
  end

  # implement IO device

  # Plain chardata – used by IO.write/2, IO.puts/2, :io.format/3 (binary data)
  defp io_handle({:put_chars, _enc, chars}, state) do
    IO.write(state.original_group_leader, chars)
    {:ok, :ok, state}
  end

  # MFA (Module-Function-Argument) variant – used by :io.format/3
  defp io_handle({:put_chars, _enc, m, f, a}, state) do
    data = apply(m, f, a)
    IO.write(state.original_group_leader, data)
    {:ok, :ok, state}
  end

  # One line (terminates on newline) – used by IO.gets/2, :io.read/1, etc.
  defp io_handle({:get_line, _enc, prompt}, state) do
    line = IO.gets(state.original_group_leader, prompt)
    {:ok, line, state}
  end

  # Fixed-length read – used by IO.read/2 or :io.get_chars/4
  defp io_handle({:get_chars, _enc, prompt, n}, state) do
    data = IO.binread(state.original_group_leader, n) || :eof
    if prompt != "", do: IO.write(state.original_group_leader, prompt)
    {:ok, data, state}
  end

  # Accept call, but do nothing
  defp io_handle(:getopts, state), do: {:ok, [], state}
  defp io_handle({:setopts, _opts}, state), do: {:ok, :ok, state}
  defp io_handle(:close, state), do: {:ok, :ok, state}

  # Anything we don't understand
  defp io_handle(_unknown, state), do: {:error, :not_supported, state}

  # end implementing IO device

  defp prepare_formatted_diff_and_new_code(opts, state) do
    if opts[:expected_type] == :file do
      {:ok,
       %{
         diff: AssertValue.Diff.diff(opts[:expected_value], opts[:actual_value])
       }}
    else
      current_line_number =
        current_line_number(
          state.file_changes,
          opts[:caller][:file],
          opts[:caller][:line]
        )

      case AssertValue.Parser.parse_assert_value(
             opts[:caller][:file],
             current_line_number,
             opts[:assertion_ast],
             opts[:actual_ast],
             opts[:expected_ast]
           ) do
        {:ok, parsed} ->
          formatter_options = formatter_options_for_file(opts[:caller][:file])

          new_expected =
            AssertValue.Formatter.new_expected_from_actual_value(
              opts[:actual_value]
            )

          new_assert_value =
            parsed.assert_value_prefix <>
              new_expected <>
              parsed.assert_value_suffix

          # Format old assert value with formatter to diff it against
          # new assert_value. This way user will see only expected value
          # diff without mixing it with formatting diff
          old_assert_value =
            AssertValue.Formatter.format_with_indentation(
              parsed.assert_value,
              parsed.indentation,
              formatter_options
            )

          new_assert_value =
            AssertValue.Formatter.format_with_indentation(
              new_assert_value,
              parsed.indentation,
              formatter_options
            )

          diff = AssertValue.Diff.diff(old_assert_value, new_assert_value)

          new_file_content = parsed.prefix <> new_assert_value <> parsed.suffix

          {:ok,
           %{
             diff: diff,
             new_file_content: new_file_content,
             old_assert_value: parsed.assert_value,
             new_assert_value: new_assert_value
           }}

        {:error, :parse_error} ->
          {:error, :parse_error}
      end
    end
  end

  defp prompt_for_action(diff, opts, state) do
    if state.recurring_answer do
      {state.recurring_answer, state}
    else
      print_diff_and_context(diff, opts, state)
      get_answer(diff, opts, state)
    end
  end

  defp print_diff_and_context(diff, opts, state) do
    file =
      opts[:caller][:file]
      # make it shorter
      |> Path.relative_to(File.cwd!())

    line = opts[:caller][:line]
    # the prompt we print here should
    # * let user easily identify which assert failed
    # * work with editors's automatic go-to-error-line file:line:
    #   format handling
    # * not be unreasonably long, so the user sees it on the screen
    #   grouped with the diff
    {function, _} = opts[:caller][:function]
    # We don't need to print context when showing diff for assert_value
    # statement because all context is in diff. But we still need to print
    # context when showing diff for File.read! Because we show only diff
    # for file contents in that case.
    diff_context =
      if opts[:expected_type] == :file do
        code = opts[:assertion_ast] |> Macro.to_string() |> smart_truncate(40)
        "#{file}:#{line}:\"#{function}\" assert_value #{code} failed"
      else
        "#{file}:#{line}:\"#{function}\" assert_value failed"
      end

    diff_lines_count = String.split(diff, "\n") |> Enum.count()
    IO.puts(state.original_group_leader, "\n" <> diff_context <> "\n")
    IO.puts(state.original_group_leader, diff)
    # If diff is too long diff context does not fit to screen
    # we need to repeat it
    if diff_lines_count > 37, do: IO.puts(state.original_group_leader, diff_context)
  end

  defp get_answer(diff, opts, state) do
    answer =
      IO.gets(state.original_group_leader, "Accept new value? [y,n,?] ")
      |> String.trim_trailing("\n")

    case answer do
      "?" ->
        print_help(state)
        get_answer(diff, opts, state)

      "d" ->
        print_diff_and_context(diff, opts, state)
        get_answer(diff, opts, state)

      c when c in ["Y", "N"] ->
        # Save answer in state and use it in future
        {c, %{state | recurring_answer: c}}

      _ ->
        {answer, state}
    end
  end

  defp print_help(state) do
    help =
      """

      y - Accept new value as correct. Will update expected value. Test will pass
      n - Reject new value. Test will fail
      Y - Accept all. Will accept this and all following new values in this run
      N - Reject all. Will reject this and all following new values in this run
      d - Show diff between actual and expected values
      ? - This help
      """
      # Indent all lines
      |> String.replace(~r/^/m, "    ")

    IO.puts(state.original_group_leader, help)
  end

  # Helpers to keep changes we make to files on updating expected values

  def current_line_number(file_changes, filename, original_line_number) do
    current_file_changes = file_changes[filename] || %{}

    cumulative_offset =
      Enum.reduce(current_file_changes, 0, fn {l, o}, total ->
        if original_line_number > l, do: total + o, else: total
      end)

    original_line_number + cumulative_offset
  end

  def update_line_numbers(
        file_changes,
        filename,
        original_line_number,
        old_expected,
        new_expected
      ) do
    offset = length(to_lines(new_expected)) - length(to_lines(old_expected))

    current_file_changes =
      (file_changes[filename] || %{})
      |> Map.put(original_line_number, offset)

    Map.put(file_changes, filename, current_file_changes)
  end

  # Use user's formatter options but force locals_without_parens
  # for assert_value
  defp formatter_options_for_file(file) do
    # Handle deprecation and maintain backward compatibility:
    #
    #   * `formatter_for_file` was introduced in Elixir >= 1.13
    #   * `formatter_opts_for_file` was deprecated in Elixir >= 1.17
    #
    # The code below calls `formatter_for_file` when available, and
    # falls back to `formatter_opts_for_file` in older versions
    #
    # `apply` keeps the compiler from emitting "deprecated” or
    # “undefined function” warnings
    # `apply` is considered unnecessary when the module and function names
    # are known, so we also suppress Credo that would normally flag it
    opts =
      if function_exported?(Mix.Tasks.Format, :formatter_for_file, 2) do
        # credo:disable-for-next-line
        {_, opts} = apply(Mix.Tasks.Format, :formatter_for_file, [file, []])
        opts
      else
        # credo:disable-for-next-line
        apply(Mix.Tasks.Format, :formatter_opts_for_file, [file])
      end

    # Force locals_without_parens for assert_value. We don't eval
    # formatter options from all user dependencies (including assert_value).
    # Also user may not add "import_deps: [:assert_value]" to .formatter.exs
    forced_options = MapSet.new(assert_value: :*)

    locals_without_parens =
      opts
      |> Keyword.get(:locals_without_parens, [])
      |> MapSet.new()
      |> MapSet.union(forced_options)
      |> MapSet.to_list()

    Keyword.put(opts, :locals_without_parens, locals_without_parens)
  end
end
