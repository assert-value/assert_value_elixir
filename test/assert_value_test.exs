defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.Test.IntegrationTest

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
