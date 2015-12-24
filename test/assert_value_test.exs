defmodule AssertValueTest do
  use ExUnit.Case

  doctest AssertValue.FileOffsets
  doctest AssertValue

  import AssertValue

  test "prototype pass" do
    actual = """
    aaa
    bbb
    """
    assert_value actual == """
    aaa
    bbb
    """
  end

  test "heredoc and file" do
    actual = """
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    """
    assert_value actual == File.read!(Path.expand("data1.log", __DIR__))
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
    assert_value actual == File.read!(Path.expand("data2.log", __DIR__))
  end

  test "heredoc and heredoc" do
    actual = """
    aaa
    bbb
    ccc
    ddd
    eee
    fff
    """
    assert_value actual == """
    aaa
    bbb
    cCc
    ddd
    eee
    fff
    """
  end

  test "string and heredoc" do
    actual = "aaa\nbbb\nccc\nddd\neee\nfff"
    assert_value actual == """
    aaa
    bbb
    cCc
    ddd
    eee
    fff
    """
  end

  test "wrong expected type" do
    actual = "foo"
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == 1
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == "bar"
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == []
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == {}
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value actual == %{}
      end)
    end
  end

end
