defmodule AssertValue do

  defmacro assert_value({:==, _, [left, right]} = assertion) do
    # Check if right argument is "File.read!"
    filename = try_to_parse_filename(right)
    code = Macro.to_string(assertion)
    expr = Macro.escape(assertion)
    quote do
      left  = unquote(left)
      right = unquote(right)
      result = (to_string(left) == to_string(right))
      case result do
        false ->
          answer = AssertValue.prompt_for_action(unquote(code), left, right)
          case answer do
            "y" ->
              AssertValue.update_expected(left, right, unquote(filename))
             _  ->
              raise ExUnit.AssertionError, [
                left: left,
                right: right,
                expr: unquote(expr),
                message: "AssertValue assertion failed"
              ]
          end
        _ -> result
      end
    end
  end

  defp try_to_parse_filename(ast) do
    try do
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} = ast
      filename
    rescue
      MatchError -> nil
    end
  end

  def update_expected(_, expected, nil) when is_binary(expected) do
    IO.puts "Update String not yet implemented"
  end

  def update_expected(_, expected, nil) when is_list(expected) do
    IO.puts "Update Heredoc not yet implemented"
  end

  def update_expected(actual, _, filename) when is_binary(filename) do
    IO.inspect "Updating #{filename}"
    res = File.write!(filename, actual)
    IO.inspect res
  end


  def prompt_for_action(code, left, right) do
    # HACK: Let ExUnit event handler to finish output
    # Otherwise ExUnit output will interfere with our output
    # Since this is interactive part 10 millisecond is not a big deal
    :timer.sleep(10)
    IO.puts "\n<Failed Assertion Message>"
    IO.puts "    #{code}\n"
    IO.puts diff(right, left)
    IO.gets("Accept new value [y/n]? ")
    |> String.rstrip(?\n)
  end

  @prefixes %{eq: " ", ins: "+", del: "-"}

  def diff(a, b) do
    a = to_string_list a
    b = to_string_list b
    format_diff :tdiff.diff(a, b)
  end

  defp to_string_list(string_or_char_list) do
    string_or_char_list
    |> to_string
    |> String.rstrip(?\n)
    |> String.split("\n")
  end

  defp format_diff(diff) do
    formatted =
      diff
      |> Enum.map(fn({k,v}) ->
          Enum.map(v, fn(s) ->
            @prefixes[k] <> s
          end)
        end)
      |> List.flatten
      |> Enum.join("\n")
    (formatted <> "\n") |> to_char_list
  end

end
