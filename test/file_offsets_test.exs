defmodule AssertValue.FileOffsetsTest do
  use ExUnit.Case

  import AssertValue.FileOffsets, only: [get_line_offset: 2, set_line_offset: 3]

  test "cumulative offsets" do
    assert get_line_offset("~/test.exs", 2) == 0
    set_line_offset("~/test.exs", 5, -2)
    assert get_line_offset("~/test.exs", 2) == 0
    assert get_line_offset("~/test.exs", 6) == -2
    set_line_offset("~/test.exs", 2, 3)
    assert get_line_offset("~/test.exs", 6) == 1
    set_line_offset("~/test.exs", 10, 5)
    assert get_line_offset("~/test.exs", 10) == 1
    assert get_line_offset("~/test.exs", 11) == 6
  end

  test "different files" do
    assert get_line_offset("~/first_test.exs", 2) == 0
    set_line_offset("~/first_test.exs", 5, -2)
    set_line_offset("~/first_test.exs", 7, 3)
    set_line_offset("~/second_test.exs", 2, 3)
    set_line_offset("~/second_test.exs", 5, 1)
    assert get_line_offset("~/first_test.exs", 6) == -2
    assert get_line_offset("~/first_test.exs", 7) == -2
    assert get_line_offset("~/first_test.exs", 8) == 1
    assert get_line_offset("~/second_test.exs", 1) == 0
    assert get_line_offset("~/second_test.exs", 2) == 0
    assert get_line_offset("~/second_test.exs", 3) == 3
    assert get_line_offset("~/second_test.exs", 6) == 4
  end


end
