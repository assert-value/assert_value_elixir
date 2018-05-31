defmodule DiffTest do
  use ExUnit.Case, async: true

  import AssertValue

  def make_lines(str) do
    str
    |> String.graphemes()
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  def make_assert_value_diff(a, b) do
    AssertValue.Diff.diff(make_lines(a), make_lines(b))
  end

  def make_system_diff(a, b) do
    a = make_lines(a)
    b = make_lines(b)

    {:ok, a_tmp} = Temp.path
    {:ok, b_tmp} = Temp.path
    File.write!(a_tmp, a)
    File.write!(b_tmp, b)

    diff_cmd = System.find_executable("diff")
    {diff, 1} = System.cmd(diff_cmd, ["-u", a_tmp, b_tmp])
    # Cut first two lines
    diff = String.split(diff, "\n")
    diff
    |> Enum.take(2 - length(diff))
    |> Enum.join("\n")
  end

  test "hunk at the beginning" do
    {a, b} = {
      "a.......",
      "b......."
    }
    diff = make_assert_value_diff(a, b)
    assert_value diff == """
                 @@ -1,4 +1,4 @@
                 -a
                 +b
                  .
                  .
                  .
                 """
    assert diff == make_system_diff(a, b)
  end

  test "hunk at the end" do
    {a, b} = {
      ".......a",
      ".......b"
    }
    diff = make_assert_value_diff(a, b)
    assert_value diff == """
                 @@ -5,4 +5,4 @@
                  .
                  .
                  .
                 -a
                 +b
                 """
    assert diff == make_system_diff(a, b)
  end

  test "hunk in the middle" do
    {a, b} = {
      ".......aaa.......",
      ".......bb......."
    }
    diff = make_assert_value_diff(a, b)
    assert_value diff == """
                 @@ -5,9 +5,8 @@
                  .
                  .
                  .
                 -a
                 -a
                 -a
                 +b
                 +b
                  .
                  .
                  .
                 """
    assert diff == make_system_diff(a, b)
  end

  test "all hunks" do
    {a, b} = {
      "aa.........aaa........a",
      "b.........bbbb........b"
    }
    diff = make_assert_value_diff(a, b)
    assert_value diff == """
                 @@ -1,5 +1,4 @@
                 -a
                 -a
                 +b
                  .
                  .
                  .
                 @@ -9,9 +8,10 @@
                  .
                  .
                  .
                 -a
                 -a
                 -a
                 +b
                 +b
                 +b
                 +b
                  .
                  .
                  .
                 @@ -20,4 +20,4 @@
                  .
                  .
                  .
                 -a
                 +b
                 """
    assert diff == make_system_diff(a, b)
  end

end
