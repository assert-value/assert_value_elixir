defmodule AssertValue do

  defmodule ActualArgumentError do
    defexception [message: ~S{Actual (left) argument should be a string}]
  end

  defmodule ExpectedArgumentError do
    defexception [message: ~S{Expected (right) argument should be string, heredoc ("""), or File.read!}]
  end

  # Assertions with right argument like "assert_value actual == expected"
  defmacro assert_value({:==, _, [left, right]} = assertion) do
    {expected_type, expected_file} = case right do
      # File.read!("/path/to/file")
      {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} ->
        {:file, filename}
      # string, hopefully heredoc
      str when is_binary(str) -> {:source, nil}
      # any other expression, we don't support.  But we want to wait
      # till runtime to report it, otherwise it's confusing.  TODO: or
      # maybe not confusing, may want to just put here:
      # _ -> raise AssertValue.ExpectedArgumentError
      _ -> {:unsupported_value, nil}
    end

    quote do
      assertion_code = unquote(Macro.to_string(assertion))
      actual_value = unquote(left)
      # We cannot use "if" in macro.
      # See my discussion with Jose Valim
      # https://groups.google.com/forum/#!topic/elixir-lang-talk/gOHu0O4x71g
      case is_binary(actual_value) do
        true -> :ok
        _ -> raise AssertValue.ActualArgumentError
      end
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
      expected_value =
        case expected_type do
          :source -> unquote(right) |>
              String.replace(~r/<NOEOL>\n\Z/, "", global: false)
          # TODO: should deal with a no-bang File.read instead, may
          # want to deal with different errors differently
          :file -> File.exists?(expected_file)
            && File.read!(expected_file)
            || ""
          :unsupported_value -> raise AssertValue.ExpectedArgumentError
        end

      assertion_result = (actual_value == expected_value)

      if assertion_result do
        assertion_result
      else
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
      # We cannot use "if" in macro.
      # See my discussion with Jose Valim
      # https://groups.google.com/forum/#!topic/elixir-lang-talk/gOHu0O4x71g
      case is_binary(actual_value) do
        true -> :ok
        _ -> raise AssertValue.ActualArgumentError
      end
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

end
