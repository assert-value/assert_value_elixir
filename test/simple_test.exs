defmodule SimpleTest do
  use ExUnit.Case

  import AssertValue.TestHelpers

  test "simple pass test" do
    test_case = prepare_test_case "simple_pass_test.exs"
    {result, exitcode} = run_test_case(test_case)
    assert exitcode == 0
    assert result == """
    .
    1 test, 0 failures
    """
  end

end
