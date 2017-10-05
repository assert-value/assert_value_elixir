defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  require AssertValue.IntegrationTest
  import AssertValue.IntegrationTest

  setup_all do
    # Make sure we delete temporary dir even if tests fail
    on_exit fn ->
      File.rm_rf!(AssertValue.IntegrationTest.runnable_test_dir)
    end
    :ok
  end

  # This test is different from the rest because we test here also
  # for file create/update
  test "integration" do
    # Prepare data for file comparisons (create)
    file_to_create_name = "file_to_create"
    file_to_create_after_path = Path.expand(file_to_create_name <> ".after",
      AssertValue.IntegrationTest.integration_test_dir)
    file_to_create_runnable_path = Path.expand(file_to_create_name,
      AssertValue.IntegrationTest.runnable_test_dir)
    refute File.exists?(file_to_create_runnable_path)

    # Prepare data for file comparisons (update)
    file_to_update_name = "file_to_update"
    file_to_update_before_path = Path.expand(file_to_update_name <> ".before",
      AssertValue.IntegrationTest.integration_test_dir)
    file_to_update_after_path = Path.expand(file_to_update_name <> ".after",
      AssertValue.IntegrationTest.integration_test_dir)
    file_to_update_runnable_path = Path.expand(file_to_update_name,
      AssertValue.IntegrationTest.runnable_test_dir)
    File.cp!(file_to_update_before_path, file_to_update_runnable_path)

    {runnable_path, after_path, output_path} =
      prepare_runnable_test("integration_test.exs")

    {output, exitcode} = run_tests(runnable_path)
    assert exitcode == 1 # There were failed tests

    # compare the results
    assert_value File.read!(runnable_path) == File.read!(after_path)
    assert_value output == File.read!(output_path)

    # test created/updated files
    assert_value File.read!(file_to_create_runnable_path) ==
      File.read!(file_to_create_after_path)
    assert_value File.read!(file_to_update_runnable_path) ==
      File.read!(file_to_update_after_path)
  end

  integration_test "diff and help promt", "diff_and_help_prompt_test.exs",
    exitcode: 1 # There should be failed tests

  integration_test "accept all (Y)", "accept_all_test.exs",
    exitcode: 0 # No failed tests

  integration_test "accept all with errors (Y)", "accept_all_with_error_test.exs",
    exitcode: 1

  integration_test "decline(Y)", "decline_all_test.exs",
    exitcode: 1

end
