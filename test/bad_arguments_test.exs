defmodule AssertValue.BadArgumentsTest do
  use ExUnit.Case

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

end
