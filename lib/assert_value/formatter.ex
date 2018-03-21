defmodule AssertValue.Formatter do

  import AssertValue.StringTools

  #{:assert_value, [no_parens: true, line: 2],
  #	 [
  #	   {:==, [line: 5],
  #		[
  #		  {:__block__, [format: :bin_heredoc, line: 2], ["aaa\nbbb\n"]},
  #		  {:__block__, [line: 5], [:foo]}
  #		]}
  #	 ]}}
  #def update_and_format(code, actual_value, indentation) do
  def update_and_format(code, actual_value, indentation) do
    detailed_ast =
      Code.string_to_quoted!(code, unescape: false, formatter_metadata: true)

    {:assert_value, meta, args} = detailed_ast
    expected_ast =
      if is_binary(actual_value) and String.contains?(actual_value, "\n") do
        actual_value = add_noeol_if_needed(actual_value)
        {:__block__, [format: :bin_heredoc], [actual_value]}
      else
        actual_value
        |> Macro.to_string()
        |> Code.string_to_quoted!(unescape: false, formatter_metadata: true)
      end

    {operator, args_meta, actual_ast} =
      case args do
        [{operator, args_meta, [actual_ast, _expected_ast]}]
            when operator in [:==, :===] ->
          {operator, args_meta, actual_ast}
        actual_ast ->
          {:==, [], actual_ast}
      end

    {doc, _} =
      {:assert_value, meta, [
        {operator, args_meta, [
          actual_ast,
          expected_ast
        ]}
      ]}
      |> AssertValue.Vendor.Elixir.Code.Formatter.quoted_to_algebra # Our hack

    doc
    |> Inspect.Algebra.format(80 - String.length(indentation))
    |> IO.iodata_to_binary
    |> format(indentation)
  end

  defp format(code, indentation) do
    code
    # Force formatter to respect non-parens call to assert_value
    # by telling it we don't use them
    |> String.replace(~r/^assert_value\(/, "assert_value ")
    |> String.replace(~r/\)$/, "")
    |> Code.format_string!(locals_without_parens: [assert_value: :*])
    |> IO.iodata_to_binary
    |> to_lines
    |> Enum.map(&(indentation <> &1))
    |> Enum.join("\n")
  end

  # to work as a heredoc a string must end with a newline.  For
  # strings that don't we append a special token and a newline when
  # writing them to source file.  This way we can look for this
  # special token when we read it back and strip it at that time.
  defp add_noeol_if_needed(arg) do
    if String.at(arg, -1) == "\n" do
      arg
    else
      arg <> "<NOEOL>\n"
    end
  end

end
