ExUnit.start(timeout: :infinity)

defmodule AssertValue.IntegrationTest.Support do
  # This helper is used to start external process, feed it with input,
  # and collect output.
  #
  # Inspired by Sasa Juric's post about running external programs with
  # Elixir's Port module:
  #   http://theerlangelist.blogspot.com/2015/08/outside-elixir.html
  #
  # and Alexei Sholik's Porcelain basic driver
  #   https://github.com/alco/porcelain/tree/master/lib/porcelain/drivers
  #
  # Usage example:
  # Run integration test session as external process, provide "yes" answers
  # for two prompts, and collect output and test results code:
  #
  #   {output, exit_code} = AssertValue.System.exec("mix",
  #      ["test", "--seed", "0", "/tmp/intergration_test.exs"], input: "y\ny\n")
  def exec(cmd, args, env, opts) do
    cmd = cmd |> System.find_executable()

    port =
      Port.open(
        {:spawn_executable, cmd},
        [{:args, args}, {:env, env}, :binary, :exit_status]
      )

    Port.command(port, opts[:input])
    handle_output(port, "")
  end

  # This function recursively collects data provided by external
  # process indentified with port until it get :exit_status message.
  defp handle_output(port, output) do
    receive do
      {^port, {:data, data}} ->
        handle_output(port, output <> data)

      {^port, {:exit_status, exit_code}} ->
        {output, exit_code}
    end
  end

  @integration_test_dir Path.expand("integration", __DIR__)

  def prepare_runnable_test(basename, runnable_test_dir) do
    before_path = Path.expand(basename <> ".before", @integration_test_dir)
    after_path = Path.expand(basename <> ".after", @integration_test_dir)
    output_path = Path.expand(basename <> ".output", @integration_test_dir)
    # Due to difference in formatter we may need different output
    # files for different Elixir versions
    after_path = latest_compatible_output_file(System.version(), after_path)
    output_path = latest_compatible_output_file(System.version(), output_path)
    # copy the test to a temp dir for running
    runnable_path = Path.expand(basename, runnable_test_dir)
    File.cp!(before_path, runnable_path)
    {runnable_path, after_path, output_path}
  end

  def latest_compatible_output_file(version, path) do
    versioned_paths = Path.wildcard("#{path}.*")

    if Enum.empty?(versioned_paths) do
      path
    else
      compatible_versions =
        versioned_paths
        # get version from filename "parser_test.exs.output.1.8" => "1.8"
        |> Enum.map(&String.replace(&1, "#{path}.", ""))
        # find compatible versions
        |> Enum.filter(&Version.match?(version, "~>#{&1}"))

      if Enum.empty?(compatible_versions) do
        path
      else
        latest_compatible_version =
          compatible_versions
          |> Enum.max_by(&Version.parse("#{&1}.0"))

        "#{path}.#{latest_compatible_version}"
      end
    end
  end

  def run_tests(filename, env \\ []) do
    # extract expected assert_value prompt responses from the test.
    # We look for lines like '# prompt: y'
    prompt_responses =
      Regex.scan(~r/#\s*prompt:\s*(.)/, File.read!(filename))
      |> Enum.map_join("\n", fn [_, x] -> x end)
      |> Kernel.<>("\n")

    # Elixir 1.13 changed default failed testcase exit status to 2
    # and introduced --exit-status param
    exec_params =
      if Version.match?(System.version(), ">= 1.13.0") do
        ["test", "--seed", "0", "--exit-status", "1", filename]
      else
        ["test", "--seed", "0", filename]
      end

    {output, exit_code} =
      AssertValue.IntegrationTest.Support.exec(
        "mix",
        exec_params,
        env,
        input: prompt_responses
      )

    # Canonicalize output
    output =
      output
      |> String.replace(~r/Running ExUnit with seed.*\n+/m, "\n")
      |> String.replace(~r{\/tmp\/assert-value-\w+/}, "")
      |> String.replace(~r/\n+Finished in[^\n]+\n+/m, "\n")
      |> String.replace(~r/\n+(\d+ tests)/m, "\n\\1")
      |> String.replace(~r/\nRandomized with seed.*\n/m, "")
      # mask line numbers
      |> String.replace(~r/(_test.exs:)\d+/, "\\1##")
      # canonicalize ExUnit error formatting:
      # - remove fancy spacing
      |> String.replace(~r/\s{5}code:\s+actual/m, "     code: actual")
      |> String.replace(~r/\s{5}(left):\s+"/m, "     left: \"")
      |> String.replace(~r/\s{5}(right):\s+"/m, "     right: \"")
      # canonicalize messages about raised exceptions
      # ExUnit in Elixir 1.5 has "code:" line in message:
      #
      #   ** (RuntimeError) Error!
      #   code: raise "Error!"
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      # ExUnit in Elixir 1.4 does not
      #
      #   ** (RuntimeError) Error!
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      |> String.replace(
        ~r/(\*\* \(.*?Error\).*?)\n\s{5}code:.*?\n/,
        "\\1\n"
      )
      |> String.trim("\n")
      |> Kernel.<>("\n")

    {output, exit_code}
  end

  def prepare_expected_files(filenames, runnable_test_dir) do
    Enum.map(filenames, fn filename ->
      before_path = Path.expand(filename <> ".before", @integration_test_dir)
      after_path = Path.expand(filename <> ".after", @integration_test_dir)
      runnable_path = Path.expand(filename, runnable_test_dir)

      if File.exists?(before_path) do
        File.cp!(before_path, runnable_path)
      end

      [runnable_path, after_path]
    end)
  end

  # Integration test flow:
  # * Copy integration_test.exs.before to runnable_test_dir
  # * launch a child `mix test integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy
  #
  # We build the integration test module instead of just test to run
  # integration tests async
  #
  # Usage:
  #
  # import AssertValue.IntegrationTest.Support, only: [build_test_module: 3]
  # build_test_module :ParserTest, "parser_test.exs",
  #   env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  #   expected_exit_code: 0,
  #   expected_files: ["file_to_create", "file_to_update"]
  #
  defmacro build_test_module(module_name, test_filename, opts \\ []) do
    expected_files = Keyword.get(opts, :expected_files, [])
    expected_exit_code = Keyword.get(opts, :expected_exit_code, 0)
    runnable_test_dir = make_temp_dir("assert-value")
    test_name = "running integration #{module_name}"

    quote do
      defmodule unquote(module_name) do
        use ExUnit.Case, async: true

        import AssertValue

        import AssertValue.IntegrationTest.Support,
          only: [
            prepare_runnable_test: 2,
            prepare_expected_files: 2,
            run_tests: 2
          ]

        setup_all do
          # Make sure we delete temporary dir even if tests fail
          on_exit(fn ->
            File.rm_rf!(unquote(runnable_test_dir))
          end)

          :ok
        end

        test unquote(test_name) do
          {runnable_path, after_path, output_path} =
            prepare_runnable_test(
              unquote(test_filename),
              unquote(runnable_test_dir)
            )

          expected_files =
            prepare_expected_files(
              unquote(expected_files),
              unquote(runnable_test_dir)
            )

          {output, exit_code} = run_tests(runnable_path, unquote(opts[:env]))
          assert exit_code == unquote(expected_exit_code)
          test_source_result = File.read!(runnable_path)
          # Make sure resulting test file is valid Elixir code
          # Will raise SyntaxError or TokenMissingError otherwise
          Code.string_to_quoted!(test_source_result)
          assert_value test_source_result == File.read!(after_path)
          assert_value output == File.read!(output_path)

          Enum.each(expected_files, fn [runnable_path, after_path] ->
            assert_value(File.read!(runnable_path) == File.read!(after_path))
          end)
        end
      end
    end
  end

  def make_temp_dir(basename) do
    random_string =
      :rand.uniform(0x100000000)
      |> Integer.to_string(36)
      |> String.downcase()

    dirname =
      Path.expand(
        basename <> "-" <> random_string,
        System.tmp_dir!()
      )

    File.mkdir!(dirname)
    System.at_exit(fn _status -> File.rm_rf(dirname) end)
    dirname
  end
end
