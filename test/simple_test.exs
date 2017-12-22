defmodule SimpleTest do
  use ExUnit.Case, async: true

  import AssertValue

  test "foo" do
    assert_value "foo" == """
    foo<NOEOL>
    """
  end

  test "bar" do
    assert_value "bar" == "bar"
  end

end
