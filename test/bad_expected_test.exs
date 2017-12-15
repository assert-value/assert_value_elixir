defmodule BadExpectedTest do
  use ExUnit.Case

  import AssertValue

  test "wrong expected type" do
    assert_raise AssertValue.ExpectedArgumentError, fn ->
      assert_value "foo" == 1
    end
    assert_raise AssertValue.ExpectedArgumentError, fn ->
      assert_value "foo" == []
    end
    assert_raise AssertValue.ExpectedArgumentError, fn ->
      assert_value "foo" == {}
    end
    assert_raise AssertValue.ExpectedArgumentError, fn ->
      assert_value "foo" == %{}
    end
    # Heredoc is charlist. We don't know the difference between
    # charlist and list. In Elixir [65] == 'A' is true
    assert_raise AssertValue.ExpectedArgumentError, fn ->
      assert_value "foo" == '''
        foo
      '''
    end
    # See test/integration/integration_test.exs.before for test expected
    # in the form of string
  end

end
