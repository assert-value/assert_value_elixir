defmodule AssertValue.FileTrackerTest do
  use ExUnit.Case

  import AssertValue.Server, only: [current_line_number: 3, update_lines_count: 4]

  test "cumulative offsets" do
    data = %{}
    assert current_line_number(data, "~/test.exs", 2) == 2
    data = update_lines_count(data, "~/test.exs", 5, -2)
    assert current_line_number(data, "~/test.exs", 2) == 2
    assert current_line_number(data, "~/test.exs", 6) == 4
    data = update_lines_count(data, "~/test.exs", 2, 3)
    assert current_line_number(data, "~/test.exs", 6) == 7
    data = update_lines_count(data, "~/test.exs", 10, 5)
    assert current_line_number(data, "~/test.exs", 10) == 11
    assert current_line_number(data, "~/test.exs", 11) == 17
  end

  test "different files" do
    data = %{}
    assert current_line_number(data, "~/first_test.exs", 2) == 2
    data =
      data
      |> update_lines_count("~/first_test.exs", 5, -2)
      |> update_lines_count("~/first_test.exs", 7, 3)
      |> update_lines_count("~/second_test.exs", 2, 3)
      |> update_lines_count("~/second_test.exs", 5, 1)
    assert current_line_number(data, "~/first_test.exs", 6) == 4
    assert current_line_number(data, "~/first_test.exs", 7) == 5
    assert current_line_number(data, "~/first_test.exs", 8) == 9
    assert current_line_number(data, "~/second_test.exs", 1) == 1
    assert current_line_number(data, "~/second_test.exs", 2) == 2
    assert current_line_number(data, "~/second_test.exs", 3) == 6
    assert current_line_number(data, "~/second_test.exs", 6) == 10
  end


end
