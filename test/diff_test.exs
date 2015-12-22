defmodule AssertValue.DiffTest do
  use ExUnit.Case

  import AssertValue.Diff

  test "text_diff char lists" do
    a = '''
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    '''
    b = '''
    aaa
    xxx
    ddd
    eee
    fff
    GGG
    '''
    assert diff(a, b) == '''
     aaa
    -bbb
    -ccc
    +xxx
     ddd
     eee
     fff
    +GGG
    '''
  end

  test "text_diff strings" do
    a = "aaa\nbbb\nccc\nddd\neee\nfff\n"
    b = "aaa\nxxx\nddd\neee\nfff\nGGG\n"
    assert diff(a, b) == '''
     aaa
    -bbb
    -ccc
    +xxx
     ddd
     eee
     fff
    +GGG
    '''
  end

end
