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
    random_string = Integer.to_string(:rand.uniform(0x100000000), 36) |> String.downcase
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
    port = Port.open({:spawn_executable, cmd}, [{:args, args}, :binary, :exit_status])
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
