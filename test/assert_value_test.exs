defmodule AssertValueTest do
  use ExUnit.Case

  doctest AssertValue.FileOffsets
  doctest AssertValue

  import AssertValue

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
    assert_raise AssertValue.ArgumentError, "Expected should be in the form of heredoc or File.read!", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == 1
      end)
    end
    assert_raise AssertValue.ArgumentError, "Expected should be in the form of heredoc or File.read!", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == "bar"
      end)
    end
    assert_raise AssertValue.ArgumentError, "Expected should be in the form of heredoc or File.read!", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == []
      end)
    end
    assert_raise AssertValue.ArgumentError, "Expected should be in the form of heredoc or File.read!", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == {}
      end)
    end
    assert_raise AssertValue.ArgumentError, "Expected should be in the form of heredoc or File.read!", fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == %{}
      end)
    end
  end

end
