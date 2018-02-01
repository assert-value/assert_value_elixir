defmodule AssertValue.FileTrackerTest do
  use ExUnit.Case

  import AssertValue.Server, only: [current_line_number: 3,
    update_line_numbers: 5]

  test "cumulative offsets" do
    file_changes = %{}
    assert current_line_number(file_changes, "~/test.exs", 2) == 2
    file_changes = update_line_numbers(file_changes, "~/test.exs", 5,
      "1\n2\n3", "1")
    assert current_line_number(file_changes, "~/test.exs", 2) == 2
    assert current_line_number(file_changes, "~/test.exs", 6) == 4
    file_changes = update_line_numbers(file_changes, "~/test.exs", 2,
      "1\n2", "1\n2\n3\n4\n5")
    assert current_line_number(file_changes, "~/test.exs", 6) == 7
    file_changes = update_line_numbers(file_changes, "~/test.exs", 10,
      "0\n1\n2\n3\n4", "0\n1\n2\n3\n4\n5\n6\n7\n8\n9")
    assert current_line_number(file_changes, "~/test.exs", 10) == 11
    assert current_line_number(file_changes, "~/test.exs", 11) == 17
  end

  test "different files" do
    file_changes = %{}
    assert current_line_number(file_changes, "~/first_test.exs", 2) == 2
    file_changes =
      file_changes
      |> update_line_numbers("~/first_test.exs", 5, "0\n1\n2", "0")
      |> update_line_numbers("~/first_test.exs", 7, "0", "0\n1\n2\n3")
      |> update_line_numbers("~/second_test.exs", 2, "0", "0\n1\n2\n3")
      |> update_line_numbers("~/second_test.exs", 5, "0", "0\n1")
    assert current_line_number(file_changes, "~/first_test.exs", 6) == 4
    assert current_line_number(file_changes, "~/first_test.exs", 7) == 5
    assert current_line_number(file_changes, "~/first_test.exs", 8) == 9
    assert current_line_number(file_changes, "~/second_test.exs", 1) == 1
    assert current_line_number(file_changes, "~/second_test.exs", 2) == 2
    assert current_line_number(file_changes, "~/second_test.exs", 3) == 6
    assert current_line_number(file_changes, "~/second_test.exs", 6) == 10
  end

end
