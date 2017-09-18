defmodule BadExpectedTest do
  use ExUnit.Case

  import AssertValue

  test "wrong expected type" do
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      assert_value "foo" == 1
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      assert_value "foo" == []
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      assert_value "foo" == {}
    end
    assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
      assert_value "foo" == %{}
    end
  end

  # TODO: Make this test work.
  #
  # To do this we need to check if expected value is a string in the form
  # of heredoc and not regular string _before_ asking user about diff.
  # Since we use separate process to interact with user ExUnit.CaptureIO
  # does not work for us.
  #
  #   assert_raise AssertValue.ArgumentError, ~S{Expected should be in the form of string heredoc (""") or File.read!}, fn ->
  #     assert_value "foo" == "bar"
  #   end

end
