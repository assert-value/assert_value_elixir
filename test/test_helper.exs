ExUnit.start([timeout: :infinity])

defmodule AssertValue.Tempfile do
  def mktemp_dir(prefix \\ "", suffix \\ "") do
    name = Path.expand(generate_tmpname(prefix, suffix), System.tmp_dir!)
    File.mkdir_p!(name)
    name
  end

  # Inspired by ruby's tmpname (ruby/lib/tmpdir.rb) and elixir Plug's upload.ex
  defp generate_tmpname(prefix, suffix) do
    {_mega, sec, micro} = :os.timestamp
    pid = :os.getpid
    random_string =
      Integer.to_string(:rand.uniform(0x100000000), 36)
      |> String.downcase
    "#{prefix}#{sec}#{micro}-#{pid}-#{random_string}#{suffix}"
  end
end

defmodule AssertValue.System do
  # This helper is used to start external process, feed it with input,
  # and collect output.
  #
  # Inspired by Sasa Juric's post about running external programs with
  # Elixir's Port module:
  #   http://theerlangelist.blogspot.com/2015/08/outside-elixir.html
  #
  # and Alexei Sholik's Porcelain basic driver
  #   https://github.com/alco/porcelain/tree/master/lib/porcelain/drivers
  #
  # Usage example:
  # Run integration test session as external process, provide "yes" answers
  # for two prompts, and collect output and test results code:
  #
  #   {output, exitcode} = AssertValue.System.exec("mix",
  #      ["test", "--seed", "0", "/tmp/intergration_test.exs"], input: "y\ny\n")
  def exec(cmd, args, opts) do
    cmd = cmd |> System.find_executable
    port = Port.open({:spawn_executable, cmd},
      [{:args, args}, :binary, :exit_status])
    Port.command(port, opts[:input])
    handle_output(port, "")
  end

  # This function recursively collects data provided by external
  # process indentified with port until it get :exit_status message.
  defp handle_output(port, output) do
    receive do
      {^port, {:data, data}} ->
        handle_output(port, output <> data)
      {^port, {:exit_status, exitcode}} ->
        {output, exitcode}
    end
  end
end

defmodule AssertValue.IntegrationTest do

  require AssertValue.Tempfile

  @integration_test_dir Path.expand("integration", __DIR__)
  @runnable_test_dir AssertValue.Tempfile.mktemp_dir("assert-value-")

  def integration_test_dir do
    @integration_test_dir
  end

  def runnable_test_dir do
    @runnable_test_dir
  end

  def prepare_runnable_test(basename) do
    before_path = Path.expand(basename <> ".before", @integration_test_dir)
    after_path = Path.expand(basename <> ".after", @integration_test_dir)
    output_path = Path.expand(basename <> ".output", @integration_test_dir)

    # copy the test to a temp dir for running
    runnable_path = Path.expand(basename, @runnable_test_dir)
    File.cp!(before_path, runnable_path)
    {runnable_path, after_path, output_path}
  end

  def run_tests(filename) do
    # extract expected assert_value prompt responses from the test.
    # We look for lines like '# prompt: y'
    prompt_responses =
      Regex.scan(~r/#\s*prompt:\s*(.)/, File.read!(filename))
      |> Enum.map(fn([_, x]) -> x end)
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    {output, exitcode} = AssertValue.System.exec("mix",
      ["test", "--seed", "0", filename], input: prompt_responses)

    # Canonicalize output
    output =
      output
      |> String.replace(~r{\/tmp\/assert-value-\d+-\d+-\w+/}, "")
      |> String.replace(~r/\nFinished in.*\n/m, "")
      |> String.replace(~r/\nRandomized with seed.*\n/m, "")
      # canonicalize ExUnit error formatting:
      # - remove fancy spacing
      |> String.replace(~r/\s{5}code:\s+actual/m,   "     code: actual")
      |> String.replace(~r/\s{5}(left):\s+"/m,  "     left: \"")
      |> String.replace(~r/\s{5}(right):\s+"/m, "     right: \"")
      # canonicalize messages about raised AssertValue.ArgumentError exceptions
      # ExUnit in Elixir 1.5 has "code:" line in message:
      #
      #   ** (AssertValue.ArgumentError) ...
      #   code: assert_value "foo" = "bar"
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      # ExUnit in Elixir 1.4 does not
      #
      #   ** (AssertValue.ArgumentError) ...
      #   stacktrace:
      #     integration_test.exs:82: (test)
      #
      |> String.replace(
        ~r/(\(AssertValue.ArgumentError\).*?)\n\s{5}code:.*?\n/, "\\1\n")

    {output, exitcode}
  end

  # Integration tests flow:
  # * Copy integration_test.exs.before to @runnable_test_dir
  # * launch a child `mix test integration_test.exs`
  # * accept or reject assert_value changes when prompted
  # * compare test source file itself after the run with a reference copy
  # * compare test output with a reference copy

  # integration_test "accept all (Y)", "accept_all_test.exs", exitcode: 1
  defmacro integration_test(test_name, test_filename, opts \\ []) do
    quote do
      test unquote(test_name) do
        {runnable_path, after_path, output_path} =
          prepare_runnable_test(unquote(test_filename))

        {output, exitcode} = run_tests(runnable_path)
        assert exitcode == unquote(exitcode(opts))

        assert_value File.read!(runnable_path) == File.read!(after_path)
        assert_value output == File.read!(output_path)
      end
    end
  end

  defp exitcode(opts) do
    opts[:exitcode] || 0
  end

end
