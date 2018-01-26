defmodule AssertValue do

  # Assertions with right argument like "assert_value actual == expected"
  defmacro assert_value({:==, _, [left, right]} = assertion) do
    {expected_type, expected_file} = case right do
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} ->
        {:file, filename}
      str when is_binary(str) ->
        {:string, nil}
      _ ->
        {:other, nil}
    end
    quote do
      assertion_ast = unquote(Macro.escape(assertion))
      actual_ast = unquote(Macro.escape(left))
      actual_value = unquote(left)
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
      expected_ast = unquote(Macro.escape(right))
      expected_value =
        case expected_type do
          :string ->
              unquote(right) |>
              String.replace(~r/<NOEOL>\n\Z/, "", global: false)
          # TODO: should deal with a no-bang File.read instead, may
          # want to deal with different errors differently
          :file -> File.exists?(expected_file)
            && File.read!(expected_file)
            || ""
          :other ->
              unquote(right)
        end
      check_serializable(actual_value)
      check_string_and_file_read(actual_value, expected_type)
      # We need to check for regenerate_expected? first to disable
      # "this check/guard will always yield the same result" warnings
      if AssertValue.Server.reformat_expected? ||
          (actual_value != expected_value) do
        decision = AssertValue.Server.ask_user_about_diff(
          caller: [
            file: unquote(__CALLER__.file),
            line: unquote(__CALLER__.line),
            function: unquote(__CALLER__.function),
          ],
          assertion_ast: assertion_ast,
          actual_ast: actual_ast,
          actual_value: actual_value,
          expected_type: expected_type,
          expected_ast: expected_ast,
          expected_value: expected_value,
          expected_file: expected_file)
        case decision do
          {:ok, value} ->
            true
          {:error, :parse_error} ->
            # reraise ParseError raised in genserver
            raise AssertValue.Parser.ParseError
          {:error, :ex_unit_assertion_error, error} ->
            raise ExUnit.AssertionError, error
        end
      else
        true
      end
    end
  end

  # Assertions without right argument like (assert_value "foo")
  defmacro assert_value(assertion) do
    quote do
      assertion_ast = unquote(Macro.escape(assertion))
      actual_value = unquote(assertion)
      check_serializable(actual_value)
      decision = AssertValue.Server.ask_user_about_diff(
        caller: [
          file: unquote(__CALLER__.file),
          line: unquote(__CALLER__.line),
          function: unquote(__CALLER__.function),
        ],
        assertion_ast: assertion_ast,
        # :_not_present_ is to show the difference between
        # nil and actually not present actual/expected
        actual_ast: :_not_present_,
        actual_value: actual_value,
        expected_type: :source,
        expected_ast: :_not_present_)
      case decision do
        {:ok, value} ->
          true
        {:error, :parse_error} ->
          # reraise ParseError raised in genserver
          raise AssertValue.Parser.ParseError
        {:error, :ex_unit_assertion_error,  error} ->
          raise ExUnit.AssertionError, error
      end
    end
  end

  defmodule ArgumentError do
    defexception [:message]
  end

  def check_serializable(arg)
        when is_pid(arg)
        when is_port(arg)
        when is_reference(arg)
        when is_function(arg) do
    raise AssertValue.ArgumentError,
      message: "Unable to serialize ##{get_type(arg)}\n" <>
        "You might want to use inspect/1 to use it in assert_value"
  end
  def check_serializable(_), do: :ok

  def check_string_and_file_read(arg, _expected_type = :file) when is_binary(arg), do: :ok
  def check_string_and_file_read(arg, _expected_type = :file) do
    raise AssertValue.ArgumentError,
      message: "Unable to compare ##{get_type(arg)} with File.read!\n" <>
        "You might want to use inspect/1 for that"
  end
  def check_string_and_file_read(_, _), do: :ok

  defp get_type(arg) do
    [h | _t] = IEx.Info.info(arg)
    case h do
      # Elixir < 1.6
      {:"Data type", type} ->
        type
      # Elixir 1.6
      {"Data type", type} ->
        type
      # else CaseClauseError
    end
  end

end
