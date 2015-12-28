defmodule SimpleDiffTest do
  use ExUnit.Case

  import AssertValue

  import AssertValue.TestHelpers

  test "simple diff test" do
    test_filename = "simple_diff_test.exs"
    log_filename_with_path = test_filename |> test_log_filename_with_path
    {result, exitcode} =
      test_filename
      |> prepare_test_case
      |> run_test_case("n\n")
    assert exitcode == 1
    assert_value result == File.read!(log_filename_with_path)
  end

end
