defmodule BadExpectedTest do
  use ExUnit.Case

  import AssertValue

  test "wrong expected type" do
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value "foo" == 1
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value "foo" == "bar"
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value "foo" == []
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value "foo" == {}
      end)
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      ExUnit.CaptureIO.capture_io("y\n", fn ->
        assert_value "foo" == %{}
      end)
    end
  end

end
