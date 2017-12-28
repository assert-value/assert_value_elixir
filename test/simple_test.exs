defmodule SimpleTest do
  use ExUnit.Case, async: true

  import AssertValue

  test "foo" do
    assert_value "foo" == """
    foo<NOEOL>
    """
  end

  test "bar" do
    assert_value (1 + 2) == 3
  end

  test "baz" do
    assert_value ((1 + 2) == 3)
  end

end
