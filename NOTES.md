# Testing Strategy

Things to test:

  * Parser
  * Formatter
  * Diff

The goal is to test everything with minimal number of tests.

If we have parser test producing diff and updating expected
we don't need to add separate tests for diff and formatter
because they are already covered by parser test.

For parser we need to test that parser can parse full assertion,
actual, and expected. So we can be sure that three tests

```
assert_value :foo
assert_value :foo == :bar
assert_value "foo" == :foo
```
cover all parser tests for Atom literals. And we just need to repeat
these tests for all types and add tests for corner cases (see below)
These tests for parser also cover diff and formatter tests
for all types. And we just need corner cases tests in diff_test.exs
and formatter_test.exs

# Elixir Types

  * nil (Atom)
  * true (Atom)
  * false (Atom)
  * Atom
  * Binary
    * String
    * Heredoc
  * BitString
  * Charlist
    * Charllst
    * Charlist Heredoc
  * Date
  * Float
    * Positive
    * Negative
    * Trailing Zeroes
  * Integer
    * Positive
    * Negative
    * Underscores
  * List
  * Map
  * NaiveDateTime
  * Time
  * Tuple
  * Any (Struct)

Not Serializable

  * Function
  * PID
  * Port
  * Reference

# Form

  * Not Present (Expected Only)
  * Literal
  * Expression
  * File.read! (Expected Only)


# Corner Cases

  * assert_value nil (because of different ASTs in Elixir 1.6 and Elixir <=1.5.3)
  * trailing zero's in Float's (because of Parser implementation)

# Known Issues

  * Empty diffs:
    * ```assert_value ""```
    * ```assert_value "" == nil```
  * ```assert_value 4 == nil``` - nil displayed as empty line

