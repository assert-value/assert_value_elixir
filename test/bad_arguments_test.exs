defmodule AssertValue.BadArgumentsTest do
  use ExUnit.Case, async: true

  defmodule User do
    defstruct name: "John", age: 27
  end
  import AssertValue

  test "bad actual and no expected" do
    f = fn -> true end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value f
    end

    task = Task.async(f)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value task.pid
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value task.ref
    end
    {:ok, port} = :gen_udp.open(0)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value port
    end
    Port.close(port)
  end

  test "bad actual" do
    f = fn -> true end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value f == :foo
    end

    task = Task.async(f)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value task.pid == :foo
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value task.ref == :foo
    end
    {:ok, port} = :gen_udp.open(0)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value port == :foo
    end
    Port.close(port)
  end

  test "left argument for File.read!" do
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value nil == File.read!("file.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value true == File.read!("file.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value false == File.read!("file.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value :foo == File.read!("file.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value '0' == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value ~D[2018-01-01] == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value 0.1 == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value 1 == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value [] == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value %{} == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value ~N[2018-01-01 21:01:50] == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value ~T[23:00:07] == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value {:ok} == File.read!("any.txt")
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value %User{} == File.read!("any.txt")
    end
  end

  test "nested not-serializable type" do
    f = fn -> true end

    assert_raise AssertValue.ArgumentError, fn ->
      assert_value %{f: f}
    end

    assert_raise AssertValue.ArgumentError, fn ->
      assert_value %{f: f} == :foo
    end
  end

  test "big maps" do
    big_map =
      1..64
      |> Enum.reduce(%{}, fn(x, acc) ->
        Map.put(acc, to_string(x), x)
      end)

    if Version.match?(System.version, ">= 1.6.5") do

      # Serialized correctly in Elixirs >= 1.6.5
      assert_value big_map == %{
                     "61" => 61,
                     "58" => 58,
                     "49" => 49,
                     "10" => 10,
                     "37" => 37,
                     "24" => 24,
                     "14" => 14,
                     "12" => 12,
                     "42" => 42,
                     "36" => 36,
                     "16" => 16,
                     "4" => 4,
                     "26" => 26,
                     "64" => 64,
                     "34" => 34,
                     "32" => 32,
                     "46" => 46,
                     "8" => 8,
                     "5" => 5,
                     "3" => 3,
                     "19" => 19,
                     "9" => 9,
                     "7" => 7,
                     "50" => 50,
                     "55" => 55,
                     "13" => 13,
                     "44" => 44,
                     "52" => 52,
                     "57" => 57,
                     "2" => 2,
                     "45" => 45,
                     "11" => 11,
                     "40" => 40,
                     "15" => 15,
                     "29" => 29,
                     "17" => 17,
                     "63" => 63,
                     "25" => 25,
                     "39" => 39,
                     "28" => 28,
                     "54" => 54,
                     "59" => 59,
                     "18" => 18,
                     "27" => 27,
                     "35" => 35,
                     "23" => 23,
                     "31" => 31,
                     "43" => 43,
                     "6" => 6,
                     "41" => 41,
                     "30" => 30,
                     "20" => 20,
                     "22" => 22,
                     "21" => 21,
                     "62" => 62,
                     "56" => 56,
                     "48" => 48,
                     "38" => 38,
                     "51" => 51,
                     "47" => 47,
                     "1" => 1,
                     "60" => 60,
                     "33" => 33,
                     "53" => 53
                   }

    else

      # But not in Elixirs < 1.6.5
      stderr_output = ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert_raise AssertValue.ArgumentError, fn ->
          assert_value big_map
        end
      end)

      # Also emits warning
      # credo:disable-for-lines:2 Credo.Check.Readability.MaxLineLength
      assert_value stderr_output == """
      \e[33mwarning: \e[0mvariable \"...\" does not exist and is being expanded to \"...()\", please use parentheses to remove the ambiguity or change the variable name
        nofile:1
      
      """

    end
  end

end
