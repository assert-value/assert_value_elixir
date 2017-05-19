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

  # Integration tests flow:
  # * Copy integration_test.exs.before to @runnable_test_dir
  # * launch a child `mix test integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy
  test "integration" do
    basename = "integration_test.exs"
    before_path = Path.expand(basename <> ".before", @integration_test_dir)
    after_path = Path.expand(basename <> ".after", @integration_test_dir)
    output_path = Path.expand(basename <> ".output", @integration_test_dir)

    # copy the test to a temp dir for running
    runnable_path = Path.expand(basename, @runnable_test_dir)
    File.cp!(before_path, runnable_path)

    # Prepare data for file comparisons (create)
    file_to_create_name = "file_to_create"
    file_to_create_after_path = Path.expand(file_to_create_name <> ".after", @integration_test_dir)
    file_to_create_runnable_path = Path.expand(file_to_create_name, @runnable_test_dir)
    refute File.exists?(file_to_create_runnable_path)

    # Prepare data for file comparisons (update)
    file_to_update_name = "file_to_update"
    file_to_update_before_path = Path.expand(file_to_update_name <> ".before", @integration_test_dir)
    file_to_update_after_path = Path.expand(file_to_update_name <> ".after", @integration_test_dir)
    file_to_update_runnable_path = Path.expand(file_to_update_name, @runnable_test_dir)
    File.cp!(file_to_update_before_path, file_to_update_runnable_path)

    # extract expected assert_value prompt responses from the test.
    # We look for lines like '# prompt: y'
    prompt_responses =
      Regex.scan(~r/# prompt: (.)/, File.read!(runnable_path))
    |> Enum.map(fn([_, x]) -> x end)
    |>  Enum.join("\n")
    prompt_responses = prompt_responses <> "\n"

    # run the test
    %Porcelain.Result{out: output, status: exitcode} =
      Porcelain.exec("mix", ["test", "--seed", "0", runnable_path],
                     in: prompt_responses)

    # canonicalize output
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

    # compare the results
    assert_value File.read!(runnable_path) == File.read!(after_path)
    assert_value output == File.read!(output_path)
    assert exitcode == 1 # One fail

    assert_value File.read!(file_to_create_runnable_path) == File.read!(file_to_create_after_path)
    assert_value File.read!(file_to_update_runnable_path) == File.read!(file_to_update_after_path)
  end

end
