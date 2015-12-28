defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.TestHelpers

  test "simple pass" do
    {result, exitcode, log_filename} =
      prepare_and_run_test_case("simple_pass_test.exs")
    assert exitcode == 0
    assert_value result == File.read!(log_filename)
  end

  test "simple diff" do
    {result, exitcode, log_filename} =
      prepare_and_run_test_case("simple_diff_test.exs", "n\n")
    assert exitcode == 1
    assert_value result == File.read!(log_filename)
  end

  test "update expected" do
    test_source_filename = "update_expected_test.exs"
    {result, exitcode, log_filename} = prepare_and_run_test_case(test_source_filename, "y\n")
    assert exitcode == 0
    assert_value result == File.read!(log_filename)
    diff_log = "update_expected_test_diff.log" |> Path.expand(log_dir)
    assert_value test_source_diff(test_source_filename) == File.read!(diff_log)
  end

  test "create expected" do
    test_source_filename = "create_expected_test.exs"
    {result, exitcode, log_filename} = prepare_and_run_test_case(test_source_filename, "y\n")
    assert exitcode == 0
    assert_value result == File.read!(log_filename)
    diff_log = "create_expected_test_diff.log" |> Path.expand(log_dir)
    assert_value test_source_diff(test_source_filename) == File.read!(diff_log)
  end

end
