ExUnit.start()

defmodule AssertValue.Tempfile do
  def mktemp_dir(prefix \\ "", suffix \\ "") do
    name = Path.expand(generate_tmpname(prefix, suffix), System.tmp_dir!)
    File.mkdir_p!(name)
    name
  end

  # This function ispired by ruby's tmpname (ruby/lib/tmpdir.rb)
  # and elixir Plug's upload.ex
  defp generate_tmpname(prefix, suffix) do
    {_mega, sec, micro} = :os.timestamp
    pid = :os.getpid
    random_string = Integer.to_string(:rand.uniform(0x100000000), 36) |> String.downcase
    "#{prefix}#{sec}#{micro}-#{pid}-#{random_string}#{suffix}"
  end
end

defmodule AssertValue.TestHelpers do

  require AssertValue.Tempfile

  @source_dir Path.expand("tests_src", __DIR__)
  @target_dir AssertValue.Tempfile.mktemp_dir("assert-value-")

  def prepare_test_case(test_file) do
    source_filename = Path.expand(test_file <> ".src", @source_dir)
    target_filename = Path.expand(test_file, @target_dir)
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
