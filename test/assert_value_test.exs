defmodule AssertValueTest do
  use ExUnit.Case
  doctest AssertValue

  test "the truth" do
    assert 1 + 1 == 2
  end
end
