defmodule BadActualTest do
  use ExUnit.Case

  import AssertValue

  test "wrong actual type" do
    assert_raise AssertValue.ActualArgumentError, fn ->
      assert_value 42
    end
    assert_raise AssertValue.ActualArgumentError, fn ->
      assert_value []
    end
    assert_raise AssertValue.ActualArgumentError, fn ->
      assert_value {}
    end
    assert_raise AssertValue.ActualArgumentError, fn ->
      assert_value %{}
    end
    assert_raise AssertValue.ActualArgumentError, fn ->
      assert_value '42'
    end
  end

end
