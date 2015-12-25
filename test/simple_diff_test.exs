defmodule SimpleDiffTest do
  use ExUnit.Case

  import AssertValue

  import AssertValue.TestHelpers

  test "simple diff test" do
    test_case = prepare_test_case "simple_diff_test.exs"
    {result, exitcode} = run_test_case(test_case, "n\n")
    assert exitcode == 1
    assert_value result == """
    
    <Failed Assertion Message>
        actual == \"aaa\\nbBb\\nccc\\n\"
    
     aaa
    -bBb
    +bbb
     ccc
    
    Accept new value [y/n]? 
    
      1) test simple (SimpleDiffTest)
         simple_diff_test.exs:6
         AssertValue assertion failed
         code: actual == \"aaa\\nbBb\\nccc\\n\"
         lhs:  \"aaa\\nbbb\\nccc\\n\"
         rhs:  \"aaa\\nbBb\\nccc\\n\"
         stacktrace:
           simple_diff_test.exs:12
    
    
    1 test, 1 failure
    """
  end

end
