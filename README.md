# assert_value

Checks that two values are same and "magically" replaces expected value
with the actual in case the new behavior (and new actual value) is correct.

For now supports two kind of expected arguments: string heredocs or files


## Installation

Add AssertValue as a dependency to your Mix project:

```elixir
def application do
  [applications: [:assert_value]]
end

defp deps do
  [{:assert_value, "~> 0.0.1"}]
end
```

## Usage

Import AssertValue module into your test case:

```elixir
import AssertValue
```

### Testing String Values

It is better to start with no expected value

```elixir
test "fresh start" do
  assert_value "foo\n"
end
```
Then run your tests as usual with "mix test".
As a result you will see diff between expected and actual values:
```
<Failed Assertion Message>
    "foo\n"

-
+foo

Accept new value [y/n]?
```
If you accept the new value your test will be automatically modified to
```elixir
assert_value "foo\n" == """
foo
"""
```

## License

This software is licensed under [the MIT license](LICENSE).
