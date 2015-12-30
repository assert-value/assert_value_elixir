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
  test "integration test" do
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

    # run the test
    %Porcelain.Result{out: output, status: exitcode} =
      Porcelain.exec("mix", ["test", "--seed", "0", runnable_path], in: "n\ny\ny\ny\ny\ny\ny\ny\n")

    # canonicalize output
    output =
      output
    |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
    |> String.replace(~r/\nFinished in.*\n/m, "")
    |> String.replace(~r/\nRandomized with seed.*\n/m, "")

    # compare the results
    assert exitcode == 1 # One fail
    assert_value output == File.read!(output_path)
    assert_value File.read!(runnable_path) == File.read!(after_path)

    assert_value File.read!(file_to_create_runnable_path) == File.read!(file_to_create_after_path)
    assert_value File.read!(file_to_update_runnable_path) == File.read!(file_to_update_after_path)
  end

end
