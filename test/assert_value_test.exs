defmodule AssertValueTest do
  use ExUnit.Case
  doctest AssertValue
  import AssertValue

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

  test "prototype pass" do
    actual = '''
    aaa
    bbb
    '''
    assert_value actual == '''
    aaa
    bbb
    '''
  end

  test "heredoc and file" do
    actual = '''
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    '''
    assert_value actual == File.read!(__DIR__ <> "/data1.log")
  end

  test "string and file" do
    actual = "
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    "
    assert_value actual == File.read!(__DIR__ <> "/data2.log")
  end

  test "heredoc and heredoc" do
    actual = '''
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    '''
    assert_value actual == '''
    aaa
    bbb
    cCc
    ddd
    eee
    fff
    '''
  end

  test "string and heredoc" do
    actual = "aaa\nbbb\nccc\nddd\neee\nfff"
    assert_value actual == '''
    aaa
    bbb
    cCc
    ddd
    eee
    fff
    '''
  end

  test "wrong expected type" do
    actual = "foo"
    assert_raise FunctionClauseError, "no function clause matching in AssertValue.update_expected/5", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == 1
      end)
    end
    assert_raise FunctionClauseError, "no function clause matching in AssertValue.update_expected/5", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == "bar"
      end)
    end
    assert_raise ArithmeticError, "bad argument in arithmetic expression", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == []
      end)
    end
    assert_raise Protocol.UndefinedError, "protocol String.Chars not implemented for {}", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == {}
      end)
    end
    assert_raise Protocol.UndefinedError, "protocol String.Chars not implemented for %{}", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == %{}
      end)
    end
  end

end
