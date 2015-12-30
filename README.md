# assert_value

Checks that two values are same and "magically" replaces expected value
with the actual in case the new behavior (and new actual value) is correct.

For now supports two kind of expected arguments: string heredocs or files


## Installation

Add AssertValue as a test env dependency to your Mix project

```elixir
defp deps do
  [{:assert_value, git: "git@github.com:acunote/assert_value_elixir.git"}, only: :test]
end
```
AssertValue needs its internal application to work. Since we compile AssertValue
for test env only we need to start it manually. Add the following line to test/test_helper.exs

```elixir
AssertValue.App.start(:normal, [])
```

## Usage

### Testing String Values

It is better to start with no expected value

```elixir
import AssertValue

test "fresh start" do
  assert_value "foo"
end
```
Then run your tests as usual with "mix test".
As a result you will see diff between expected and actual values:
```
<Failed Assertion Message>
    "foo"

-
+foo

Accept new value [y/n]?
```
If you accept the new value your test will be automatically modified to
```elixir
test "fresh start" do
  assert_value "foo" == """
  foo
  """
end
```

### Testing Values Stored in Files

Sometimes test string is too large to be inlined into the test source.
Put it into the file instead.

```elixir
assert_value "foo" == File.read!("test/log/reference.txt")
```
AssertValue is smart enough to recognize File.read! and will update file contents
instead of test source. If file does not exists it will be created and no error
will be raised despite default File.read! behaviour.

## Notes and Known Issues

  * AssertValue requires left argument to be a string. However it will accept
    everything with implemented String.Chars protocol (Atom, BitString, Char List,
    Integer, Float). It will raise AssertValue.ArgumentError in all other cases.
  * Right argument should be in the form of string heredoc starting and ending
    with """ or File.read!.
  * Using plain strings as right argument will cause incorrect test source changes.
  * Using other types as right argument will raise AssertValue.ArgumentError.

## License

This software is licensed under [the MIT license](LICENSE).
