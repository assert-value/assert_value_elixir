defmodule AssertValue.DiffTest do
  use ExUnit.Case

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
  end

  test "char list diff" do
    a = 'aaa\nbbb\nccc\nddd\neee\nfff\n'
    b = "aaa\nxxx\nddd\neee\nfff\nGGG\n"
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
  end

end
