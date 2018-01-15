defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.Test.IntegrationTest

  @moduledoc """
  Things to test:

    * Parser
    * Formatter
    * Diff

  The goal is to test everything with minimal number of tests.

  If we have parser test producing diff and updating expected we don't need to
  add separate tests for diff and formatter because they are already covered
  by parser test.

  For parser we need to test that parser can parse full assertion, actual,
  and expected. So we can be sure that three tests

  ```
  assert_value :foo
  assert_value :foo == :bar
  assert_value "foo" == :foo
  ```
  cover all parser tests for Atom literals. And we just need to repeat these
  tests for all types and add tests for corner cases (see below) These tests
  for parser also cover diff and formatter tests for all types. And we just
  need corner cases tests in diff_test.exs and formatter_test.exs

  # Elixir Types

    * nil (Atom)
    * true (Atom)
    * false (Atom)
    * Atom
    * Binary
      * String
      * Heredoc
      * ~S, ~s
    * BitString
    * Charlist
      * Charllst
      * Charlist Heredoc
      * ~C, ~c
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
      * []
      * ~W
      * ~w
    * Map
    * NaiveDateTime
    * Regexp
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

  # Expressions

    * Variable
    * Parens (including recursive)
    * Left, Right expressions
    * Functions
    * Pipes

    * Expressions could be one-liners or multi-line

  We need to have two tests for each expression type
  ```
  assert_value <expr1>
  assert_value <expr1> == <expr2>
  ```
  then we are sure that we correctly these expressions type in actual
  and expected. Plus of course corner cases like nested parens, etc...

  # Corner Cases

    * assert_value nil
      because of different ASTs in Elixir 1.6 and Elixir <=1.5.3
    * trailing zero's in Float's
      because of Parser implementation

  # Known Issues

    * Empty diffs:
      * ```assert_value ""```
      * ```assert_value "" == nil```
    * ```assert_value 4 == nil``` - nil displayed as empty line

  """

  setup_all do
    # Make sure we delete temporary dir even if tests fail
    on_exit fn ->
      File.rm_rf!(AssertValue.Test.IntegrationTest.runnable_test_dir)
    end
    :ok
  end

  integration_test "parser_test", "parser_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 0,
    expected_files: ["file_to_create", "file_to_update"]

  integration_test "formatter_test", "formatter_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 0

  integration_test "diff_test", "diff_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 0

  integration_test "diff and help promt", "diff_and_help_prompt_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 1 # There should be failed tests

  integration_test "misc tests", "misc_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 1

  integration_test "accept all (Y)", "accept_all_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 0 # No failed tests

  integration_test "accept all with errors (Y)", "accept_all_with_error_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 1

  integration_test "decline (N)", "decline_all_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
    expected_exit_code: 1

  integration_test "non-interactive accept", "non_interactive_accept_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'y'}],
    expected_exit_code: 0

  integration_test "non-interactive reject", "non_interactive_reject_test.exs",
    env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'n'}],
    expected_exit_code: 1

end
