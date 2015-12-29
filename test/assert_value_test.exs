defmodule AssertValueTest do
  use ExUnit.Case

  import AssertValue
  require AssertValue.Tempfile

  # these are special integration tests. For each file we:
  # * launch a child `mix test our_integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy
  test "integration" do
    integration_test_dir = Path.expand("integration", __DIR__)
    runnable_test_dir = AssertValue.Tempfile.mktemp_dir("assert-value-")

    [["simple_pass_test.exs", "", 0],
     ["simple_diff_test.exs", "n\n", 1],
     ["update_expected_test.exs", "y\n", 0],
     ["create_expected_test.exs", "y\n", 0]] |>
      Enum.each(fn([basename, responses, expected_exit_code]) ->
        before_path = Path.expand(basename <> ".before", integration_test_dir)
        after_path = Path.expand(basename <> ".after", integration_test_dir)
        output_path = Path.expand(basename <> ".output", integration_test_dir)

        # copy the test to a temp dir for running
        runnable_path = Path.expand(basename, runnable_test_dir)
        File.cp!(before_path, runnable_path)

        # run the test
        %Porcelain.Result{out: output, status: exitcode} =
          Porcelain.exec("mix", ["test", runnable_path],
                         in: responses)
        # canonicalize output
        output =
          output
        |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
        |> String.replace(~r/\nFinished in.*\n/m, "")
        |> String.replace(~r/\nRandomized with seed.*\n/m, "")

        # compare the results
        assert exitcode == expected_exit_code
        assert_value output == File.read!(output_path)
        assert_value File.read!(runnable_path) == File.read!(after_path)
      end)
  end

end


