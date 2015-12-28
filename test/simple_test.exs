defmodule SimpleTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.TestHelpers

  test "simple pass test" do
    {result, exitcode, log_filename} =
      prepare_and_run_test_case("simple_pass_test.exs")
    assert exitcode == 0
    assert_value result == File.read!(log_filename)
  end

end
