defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  import AssertValue.TestHelpers
  
  # these are special tests that:
  # * launch a child mix with a .exs test file
  # * accept or reject assert_value changes when prompted
  # * compare both the test source file itself after this, and the
  #   captured output of the run against stored reference copies
  test "integration" do
    [["simple_pass_test", "", 0],
     ["simple_diff_test", "n\n", 1],
     ["update_expected_test", "y\n", 0],
     ["create_expected_test", "y\n", 0]] |>
      Enum.each(fn([basename, responses, expected_exit_code]) ->
        test_source_filename = basename <> ".exs"
        {result, exitcode, log_filename} =
          prepare_and_run_test_case(test_source_filename, responses)
        assert exitcode == expected_exit_code
        assert_value result == File.read!(log_filename)
        diff_log = basename <> ".exs.after" |> Path.expand(integration_tests_dir)
        assert_value test_source_diff(test_source_filename)
        == File.read!(diff_log)
      end)
  end

end
