defmodule AssertValueTest do
  use ExUnit.Case
  doctest AssertValue

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
    assert AssertValue.diff(a, b) == '''
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
    assert AssertValue.diff(a, b) == '''
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
