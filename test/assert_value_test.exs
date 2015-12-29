defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  require AssertValue.Tempfile

  @integration_test_dir Path.expand("integration", __DIR__)
  @runnable_test_dir AssertValue.Tempfile.mktemp_dir("assert-value-")

  setup_all do
    on_exit fn -> File.rm_rf!(@runnable_test_dir) end
    :ok
  end

  test "simple_pass_test.exs" do
    run_integration_test(__ENV__, "", 0)
  end

  test "simple_diff_test.exs" do
    run_integration_test(__ENV__, "n\n", 1)
  end

  test "update_expected_test.exs" do
    run_integration_test(__ENV__, "y\n", 0)
  end

  test "create_expected_test.exs" do
    run_integration_test(__ENV__, "y\n", 0)
  end

  test "update_file_test.exs" do
    filename = "file_to_update"
    file_before_path = Path.expand(filename <> ".before", @integration_test_dir)
    file_after_path = Path.expand(filename <> ".after", @integration_test_dir)
    file_runnable_path = Path.expand(filename, @runnable_test_dir)
    File.cp!(file_before_path, file_runnable_path)
    run_integration_test(__ENV__, "y\n", 0)
    assert_value File.read!(file_runnable_path) == File.read!(file_after_path)
  end


  # For each test we:
  # * launch a child `mix test our_integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy
  defp run_integration_test(env, responses, expected_exit_code) do
    # __ENV__.function returns tuple {:"test simple_pass_test.exs", 1}
    # where first argument is a generated test function name  as atom
    # and second argument is a test function arity (1 by default)
    {test_name, _} = env.function
    basename = test_name |> to_string |> String.replace(~r/^test /, "")

    before_path = Path.expand(basename <> ".before", @integration_test_dir)
    after_path = Path.expand(basename <> ".after", @integration_test_dir)
    output_path = Path.expand(basename <> ".output", @integration_test_dir)

    # copy the test to a temp dir for running
    runnable_path = Path.expand(basename, @runnable_test_dir)
    File.cp!(before_path, runnable_path)

    # run the test
    %Porcelain.Result{out: output, status: exitcode} =
      Porcelain.exec("mix", ["test", runnable_path],
                     in: responses)
    # canonicalize output
    output =
      output
    |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
    |> String.replace(~r/\nFinished in.*\n/m, "")
    |> String.replace(~r/\nRandomized with seed.*\n/m, "")

    # compare the results
    assert exitcode == expected_exit_code
    assert_value output == File.read!(output_path)
    assert_value File.read!(runnable_path) == File.read!(after_path)
  end

end
