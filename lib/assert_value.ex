defmodule AssertValue do

  defmodule ParseError do
    defexception [message: "Unable to parse assert_value arguments"]
  end

  defmodule ArgumentError do
    defexception [:message]
  end

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
      assertion_code = unquote(Macro.to_string(assertion))
      actual_code = unquote(Macro.to_string(left))
      actual_value = unquote(left)
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
      expected_code = unquote(Macro.to_string(right))
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
      check_type(actual_value)
      check_type(expected_value)
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
            actual_code: actual_code,
            actual_value: actual_value,
            expected_type: expected_type,
            expected_code: expected_code,
            expected_value: expected_value,
            expected_file: expected_file)
          case decision do
            {:ok, value} ->
              value
            {:error, :parse_error} ->
              raise AssertValue.ParseError
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
      check_type(actual_value)
      decision = AssertValue.Server.ask_user_about_diff(
        caller: [
          file: unquote(__CALLER__.file),
          line: unquote(__CALLER__.line),
          function: unquote(__CALLER__.function),
        ],
        assertion_code: assertion_code,
        actual_value: actual_value,
        expected_type: :source
      )
      case decision do
        {:ok, value} ->
          value
        {:error, :parse_error} ->
          raise AssertValue.ParseError
        {:error, :ex_unit_assertion_error,  error} ->
          raise ExUnit.AssertionError, error
      end
    end
  end

  def check_type(arg)
        when is_pid(arg)
        when is_port(arg)
        when is_reference(arg)
        when is_function(arg) do
    raise AssertValue.ArgumentError, message: "AssertValue does not " <>
    "suppport PID, Port, Reference, and Function types"
  end
  def check_type(_), do: :ok

end
