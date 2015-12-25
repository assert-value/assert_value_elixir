ExUnit.start()

defmodule AssertValue.TestHelpers do

  @source_dir Path.expand("tests_src", __DIR__)
  @target_dir Path.expand(AssertValue.Tmpname.generate("assert-value-"), System.tmp_dir!)

  def prepare_test_case(test_file) do
    source_filename = Path.expand(test_file <> ".src", @source_dir)
    target_filename = Path.expand(test_file, @target_dir)
    File.mkdir_p!(@target_dir)
    File.cp!(source_filename, target_filename)
    target_filename
  end

  def run_test_case(test_case_file, input \\ "") do
    %Porcelain.Result{out: output, status: exitcode} =
      Porcelain.exec("mix", ["test", test_case_file], in: input)
    # Serialize output
    output =
      output
      |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
      |> String.replace(~r/\nFinished in.*\n/m, "")
      |> String.replace(~r/\nRandomized with seed.*\n/m, "")
    {output, exitcode}
  end

end
