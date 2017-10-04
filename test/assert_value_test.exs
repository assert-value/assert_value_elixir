defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  require AssertValue.Tempfile

  @integration_test_dir Path.expand("integration", __DIR__)
  @runnable_test_dir AssertValue.Tempfile.mktemp_dir("assert-value-")

  setup_all do
    # Make sure we delete temporary dir even if tests fail
    on_exit fn -> File.rm_rf!(@runnable_test_dir) end
    :ok
  end

  defp prepare_runnable_test(basename) do
    before_path = Path.expand(basename <> ".before", @integration_test_dir)
    after_path = Path.expand(basename <> ".after", @integration_test_dir)
    output_path = Path.expand(basename <> ".output", @integration_test_dir)

    # copy the test to a temp dir for running
    runnable_path = Path.expand(basename, @runnable_test_dir)
    File.cp!(before_path, runnable_path)
    {runnable_path, after_path, output_path}
  end

  defp run_tests(filename) do
    # extract expected assert_value prompt responses from the test.
    # We look for lines like '# prompt: y'
    prompt_responses =
      Regex.scan(~r/#\s*prompt:\s*(.)/, File.read!(filename))
      |> Enum.map(fn([_, x]) -> x end)
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    {output, exitcode} = AssertValue.System.exec("mix",
      ["test", "--seed", "0", filename], input: prompt_responses)

    # Canonicalize output
    output =
      output
      |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
      |> String.replace(~r/\nFinished in.*\n/m, "")
      |> String.replace(~r/\nRandomized with seed.*\n/m, "")
      # canonicalize ExUnit error formatting:
      # - remove fancy spacing
      # - canonicalize lhs/rhs vs left/right
      |> String.replace(~r/\s{5}code:\s+actual/m,   "     code: actual")
      |> String.replace(~r/\s{5}(lhs|left):\s+"/m,  "     left: \"")
      |> String.replace(~r/\s{5}(rhs|right):\s+"/m, "     right: \"")
      # canonicalize messages about raised AssertValue.ArgumentError exceptions
      # ExUnit in Elixir 1.5 has "code:" line in message:
      #
      #   ** (AssertValue.ArgumentError) ...
      #   code: assert_value "foo" = "bar"
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      # ExUnit in Elixir 1.4 does not
      #
      #   ** (AssertValue.ArgumentError) ...
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      |> String.replace(
        ~r/(\(AssertValue.ArgumentError\).*?)\n\s{5}code:.*?\n/, "\\1\n")

    {output, exitcode}
  end

  # Integration tests flow:
  # * Copy integration_test.exs.before to @runnable_test_dir
  # * launch a child `mix test integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy

  test "integration" do
    {runnable_path, after_path, output_path} =
      prepare_runnable_test("integration_test.exs")

    # Prepare data for file comparisons (create)
    file_to_create_name = "file_to_create"
    file_to_create_after_path = Path.expand(file_to_create_name <> ".after",
      @integration_test_dir)
    file_to_create_runnable_path = Path.expand(file_to_create_name,
      @runnable_test_dir)
    refute File.exists?(file_to_create_runnable_path)

    # Prepare data for file comparisons (update)
    file_to_update_name = "file_to_update"
    file_to_update_before_path = Path.expand(file_to_update_name <> ".before",
      @integration_test_dir)
    file_to_update_after_path = Path.expand(file_to_update_name <> ".after",
      @integration_test_dir)
    file_to_update_runnable_path = Path.expand(file_to_update_name,
      @runnable_test_dir)
    File.cp!(file_to_update_before_path, file_to_update_runnable_path)

    {output, exitcode} = run_tests(runnable_path)
    assert exitcode == 1 # There were failed tests

    # compare the results
    assert_value File.read!(runnable_path) == File.read!(after_path)
    assert_value output == File.read!(output_path)

    assert_value File.read!(file_to_create_runnable_path) ==
      File.read!(file_to_create_after_path)
    assert_value File.read!(file_to_update_runnable_path) ==
      File.read!(file_to_update_after_path)
  end

  test "diff and help prompt" do
    {runnable_path, after_path, output_path} =
      prepare_runnable_test("diff_and_help_prompt_test.exs")

    {output, exitcode} = run_tests(runnable_path)
    assert exitcode == 1 # There were failed tests

    assert_value File.read!(runnable_path) == File.read!(after_path)
    assert_value output == File.read!(output_path)
  end

end
