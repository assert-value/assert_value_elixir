ExUnit.start()

defmodule AssertValue.TestHelpers do

  @source_dir Path.expand("tests_src", __DIR__)
  @target_dir Path.expand("tmp", __DIR__)

  def prepare_test_case(test_file) do
    source_filename = Path.expand(test_file <> ".src", @source_dir)
    target_filename = Path.expand(test_file, @target_dir)
    File.cp!(source_filename, target_filename)
    target_filename
  end

  def run_test(test_case_file) do
    {output, exitcode} = System.cmd "mix", ["test", test_case_file]
    # Serialize output
    output =
      output
      |> String.replace(~r/\nFinished in.*\n/m, "")
      |> String.replace(~r/\nRandomized with seed.*\n/m, "")
    {output, exitcode}
  end

end
