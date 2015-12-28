defmodule SimpleDiffTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.TestHelpers

  test "simple diff test" do
    {result, exitcode, log_filename} =
      prepare_and_run_test_case("simple_diff_test.exs", "n\n")
    assert exitcode == 1
    assert_value result == File.read!(log_filename)
  end

end
