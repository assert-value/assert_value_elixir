defmodule AssertValue.TestSourceChangesTest do
  use ExUnit.Case

  import AssertValue.TestSourceChanges, only: [current_line_number: 2, update_lines_count: 3]

  test "cumulative offsets" do
    assert current_line_number("~/test.exs", 2) == 2
    update_lines_count("~/test.exs", 5, -2)
    assert current_line_number("~/test.exs", 2) == 2
    assert current_line_number("~/test.exs", 6) == 4
    update_lines_count("~/test.exs", 2, 3)
    assert current_line_number("~/test.exs", 6) == 7
    update_lines_count("~/test.exs", 10, 5)
    assert current_line_number("~/test.exs", 10) == 11
    assert current_line_number("~/test.exs", 11) == 17
  end

  test "different files" do
    assert current_line_number("~/first_test.exs", 2) == 2
    update_lines_count("~/first_test.exs", 5, -2)
    update_lines_count("~/first_test.exs", 7, 3)
    update_lines_count("~/second_test.exs", 2, 3)
    update_lines_count("~/second_test.exs", 5, 1)
    assert current_line_number("~/first_test.exs", 6) == 4
    assert current_line_number("~/first_test.exs", 7) == 5
    assert current_line_number("~/first_test.exs", 8) == 9
    assert current_line_number("~/second_test.exs", 1) == 1
    assert current_line_number("~/second_test.exs", 2) == 2
    assert current_line_number("~/second_test.exs", 3) == 6
    assert current_line_number("~/second_test.exs", 6) == 10
  end


end
