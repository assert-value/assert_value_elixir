defmodule AssertValue do

  # Assertions with right argument like "assert_value actual == expected"
  defmacro assert_value({:==, _, [left, right]} = assertion) do
    # This should be performed on AST outside "quote do"
    {expected_type, expected_file} = get_expected_type(right)
    quote do
      assertion_code = unquote(Macro.to_string(assertion))
      actual_value = unquote(left)
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
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
      case (actual_value == expected_value) do
        true ->
          {:ok, actual_value}
        _ ->
          decision = AssertValue.Server.ask_user_about_diff(
            caller: [
              file: unquote(__CALLER__.file),
              line: unquote(__CALLER__.line),
              function: unquote(__CALLER__.function),
            ],
            assertion_code: assertion_code,
            actual_value: actual_value,
            expected_type: expected_type,
            expected_action: :update,
            expected_value: expected_value,
            expected_file: expected_file)
          case decision do
            {:ok, value} ->
              value
            {:error, :parse_error} ->
              raise "Unable to parse expected value"
            {:error, :ex_unit_assertion_error, error} ->
              raise ExUnit.AssertionError, error
          end
      end
    end
  end

  # Assertions without right argument like (assert_value "foo")
  defmacro assert_value(assertion) do
    quote do
      assertion_code = unquote(Macro.to_string(assertion))
      actual_value = unquote(assertion)
      decision = AssertValue.Server.ask_user_about_diff(
        caller: [
          file: unquote(__CALLER__.file),
          line: unquote(__CALLER__.line),
          function: unquote(__CALLER__.function),
        ],
        actual_value: actual_value,
        assertion_code: assertion_code,
        expected_type: :source,
        expected_action: :create,
        expected_value: nil)

      case decision do
        {:ok, value} ->
          value
        {:error, :ex_unit_assertion_error,  error} ->
          raise ExUnit.AssertionError, error
      end
    end
  end

  # File.read!("/path/to/file")
  defp get_expected_type(
    {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} = _expected
  ) do
    {:file, filename}
  end
  defp get_expected_type(expected) when is_binary(expected) do
    {:string, nil}
  end
  defp get_expected_type(_), do: {:other, nil}

end
