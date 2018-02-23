defmodule AssertValue.DiffTest do
  use ExUnit.Case, async: true

  import AssertValue.Diff

  test "diff" do
    a = """
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    """
    b = """
    aaa
    xxx
    ddd
    eee
    fff
    GGG
    """
    assert diff(a, b) == """
     aaa
    -bbb
    -ccc
    +xxx
     ddd
     eee
     fff
    +GGG
    """

    assert diff(nil, b) == """
    -
    +aaa
    +xxx
    +ddd
    +eee
    +fff
    +GGG
    """
    assert diff(a, nil) == """
    -aaa
    -bbb
    -ccc
    -ddd
    -eee
    -fff
    +
    """
  end

  test "string and integer" do
    assert diff(42, "42") == """
    -42
    +\"42\"
    """
    assert diff("42", 42) == """
    -\"42\"
    +42
    """
  end

  test "nil and integer" do
    assert diff(42, nil) == """
    -42
    +
    """
    assert diff(nil, 42) == """
    -
    +42
    """
  end

  test "char list diff" do
    a = 'aaa\nbbb\nccc\nddd\neee\nfff\n'
    b = "aaa\nxxx\nddd\neee\nfff\nGGG\n"
    assert diff(a, b) == """
    -'aaa\\nbbb\\nccc\\nddd\\neee\\nfff\\n'
    +\"aaa\\nxxx\\nddd\\neee\\nfff\\nGGG\\n\"
    """
  end

end
