#  Things to test:
#
#    * Parser
#    * Formatter
#    * Diff
#
#  The goal is to test everything with minimal number of tests.
#
#  If we have parser test producing diff and updating expected we don't need to
#  add separate tests for diff and formatter because they are already covered
#  by parser test.
#
#  For parser we need to test that parser can parse full assertion, actual,
#  and expected. So we can be sure that three tests
#
#  ```
#  assert_value :foo
#  assert_value :foo == :bar
#  assert_value "foo" == :foo
#  ```
#  cover all parser tests for Atom literals. And we just need to repeat these
#  tests for all types and add tests for corner cases (see below) These tests
#  for parser also cover diff and formatter tests for all types. And we just
#  need corner cases tests in diff_test.exs and formatter_test.exs
#
#  # Elixir Types
#
#    * nil (Atom)
#    * true (Atom)
#    * false (Atom)
#    * Atom
#    * Binary
#      * String
#      * Heredoc
#      * ~S, ~s
#    * BitString
#    * Charlist
#      * Charllst
#      * Charlist Heredoc
#      * ~C, ~c
#    * Date
#    * Float
#      * Positive
#      * Negative
#      * Trailing Zeroes
#    * Integer
#      * Positive
#      * Negative
#      * Underscores
#    * List
#      * []
#      * ~W
#      * ~w
#    * Map
#    * NaiveDateTime
#    * Regexp
#    * Time
#    * Tuple
#    * Module attributes @
#    * Any (Struct)
#
#  Not Serializable
#
#    * Function
#    * PID
#    * Port
#    * Referencea
#    * Custom types (like Decimal)
#
#  # Form
#
#    * Not Present (Expected Only)
#    * Literal
#    * Expression
#    * File.read! (Expected Only)
#
#  # Expressions
#
#    * Variable
#    * Parens (including recursive)
#    * Match operator (=)
#    * Left, Right expressions
#    ** Comparison (===, <, >, >=, <=, !=, =~)
#    ** Other (++, <>, etc...)
#    * Functions calls (named and anonymous)
#    * Pipes
#
#    * Expressions could be one-liners or multi-line
#
#  We need to have two tests for each expression type
#  ```
#  assert_value <expr1>
#  assert_value <expr1> == <expr2>
#  ```
#  then we are sure that we correctly these expressions type in actual
#  and expected. Plus of course corner cases like nested parens, etc...

import AssertValue.IntegrationTest.Support, only: [build_test_module: 3]

build_test_module(:ParserTest, "parser_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 0,
  expected_files: ["file_to_create", "file_to_update"]
)

build_test_module(:FormatterTest, "formatter_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 0
)

build_test_module(:DiffTest, "diff_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 0
)

build_test_module(:DiffAndHelpPromtTest, "diff_and_help_prompt_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  # There should be failed tests
  expected_exit_code: 1
)

build_test_module(:MiscTest, "misc_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 1
)

build_test_module(:AcceptAppTest, "accept_all_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  # No failed tests
  expected_exit_code: 0
)

build_test_module(:AcceptAllWithErrorsTest, "accept_all_with_error_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 1
)

build_test_module(:DeclineAllTest, "decline_all_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'ask'}],
  expected_exit_code: 1
)

build_test_module(:NonInteractiveAcceptTest, "non_interactive_accept_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'y'}],
  expected_exit_code: 0
)

build_test_module(:NonInteractiveRejectTest, "non_interactive_reject_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'n'}],
  expected_exit_code: 1
)

build_test_module(:ReformatExpectedTest, "reformat_expected_test.exs",
  env: [{'ASSERT_VALUE_ACCEPT_DIFFS', 'reformat'}],
  expected_exit_code: 0
)
