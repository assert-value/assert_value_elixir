defmodule AssertValue.BadArgumentsTest do
  use ExUnit.Case

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

  test "bad expected" do
    f = fn -> true end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value :foo == f
    end

    task = Task.async(f)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value :foo == task.pid
    end
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value :foo == task.ref
    end
    {:ok, port} = :gen_udp.open(0)
    assert_raise AssertValue.ArgumentError, fn ->
      assert_value :foo == port
    end
    Port.close(port)
  end

end
