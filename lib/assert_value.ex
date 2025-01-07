defmodule AssertValue do
  # Assertions with right argument like "assert_value actual == expected"
  defmacro assert_value({:==, _, [left, right]} = assertion) do
    {expected_type, expected_file} =
      case right do
        {{:., _, [{:__aliases__, _, [:File]}, :read!]}, _, [filename]} ->
          {:file, filename}

        str when is_binary(str) ->
          {:string, nil}

        _ ->
          {:other, nil}
      end

    expected_value =
      case expected_type do
        :string ->
          quote do
            unquote(right)
            |> String.replace(~r/<NOEOL>\n\Z/, "", global: false)
          end

        # TODO: should deal with a no-bang File.read instead, may
        # want to deal with different errors differently
        :file ->
          quote do
            (File.exists?(unquote(expected_file)) &&
               File.read!(unquote(expected_file))) ||
              ""
          end

        :other ->
          right
      end

    quote do
      assertion_ast = unquote(Macro.escape(assertion))
      actual_ast = unquote(Macro.escape(left))
      actual_value = unquote(left)
      expected_type = unquote(expected_type)
      expected_file = unquote(expected_file)
      expected_ast = unquote(Macro.escape(right))
      expected_value = unquote(expected_value)

      check_serializable(actual_value)
      check_string_and_file_read(actual_value, expected_type)
      # We need to check for reformat_expected? first to disable
      # "this check/guard will always yield the same result" warnings
      if AssertValue.Server.reformat_expected?() ||
           actual_value != expected_value do
        decision =
          AssertValue.Server.ask_user_about_diff(
            caller: [
              file: unquote(__CALLER__.file),
              line: unquote(__CALLER__.line),
              function: unquote(__CALLER__.function)
            ],
            assertion_ast: assertion_ast,
            actual_ast: actual_ast,
            actual_value: actual_value,
            expected_type: expected_type,
            expected_ast: expected_ast,
            expected_value: expected_value,
            expected_file: expected_file
          )

        case decision do
          :ok ->
            true

          {:error, :ex_unit_assertion_error, error_attrs} ->
            raise ExUnit.AssertionError, error_attrs

          {:error, :parse_error} ->
            # raise ParseError in test instead of genserver
            # to show readable error message and stacktrace
            raise AssertValue.Parser.ParseError
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

      decision =
        AssertValue.Server.ask_user_about_diff(
          caller: [
            file: unquote(__CALLER__.file),
            line: unquote(__CALLER__.line),
            function: unquote(__CALLER__.function)
          ],
          assertion_ast: assertion_ast,
          # :_not_present_ is to show the difference between
          # nil and actually not present actual/expected
          actual_ast: :_not_present_,
          actual_value: actual_value,
          expected_type: :source,
          expected_ast: :_not_present_
        )

      case decision do
        :ok ->
          true

        {:error, :ex_unit_assertion_error, error_attrs} ->
          raise ExUnit.AssertionError, error_attrs

        {:error, :parse_error} ->
          # raise ParseError in test instead of genserver
          # to show readable error message and stacktrace
          raise AssertValue.Parser.ParseError
      end
    end
  end

  defmodule ArgumentError do
    defexception [:message]
  end

  def check_serializable(value) do
    # Some types like Function, PID, Decimal, etc don't have literal
    # representation and cannot be used as expected
    #
    #    #Decimal<18.98>
    #
    # To check this we format actual value and try to parse it back with
    # Code.eval_string. If evaluated value is the same as it was before
    # formatting then value is serialized correctly
    {res, evaluated_value} =
      try do
        {evaluated_value, _} =
          value
          |> AssertValue.Formatter.new_expected_from_actual_value()
          |> Code.eval_string()

        evaluated_value =
          if is_binary(evaluated_value) do
            String.replace(evaluated_value, ~r/<NOEOL>\n\Z/, "", global: false)
          else
            evaluated_value
          end

        {:ok, evaluated_value}
      rescue
        _ -> {:error, nil}
      end

    unless res == :ok and value == evaluated_value do
      raise AssertValue.ArgumentError,
        message: """
        Unable to serialize #{inspect(value)}

        assert_value needs to be able to take actual value and update expected
        in source code so they are equal. To do this it needs to serialize
        Elixir value as valid Elixir source code.

        assert_value tried to serialize this expected value, and it did not
        work.

        Some types like Function, PID, Decimal don't have literal
        representation and cannot be serialized. Same goes for data
        structures that include these values.

        One way to fix this is to write your own serializer and convert
        this actual value to a string before passing it to assert_value.
        For example you can wrap actual value in Kernel.inspect/1
        """
    end

    :ok
  end

  def check_string_and_file_read(actual_value, _expected_type = :file)
      when is_binary(actual_value),
      do: :ok

  def check_string_and_file_read(actual_value, _expected_type = :file) do
    raise AssertValue.ArgumentError,
      message: """
      Unable to compare #{get_value_type(actual_value)} with File.read!

      File.read! always return binary result and requires left argument
      in assert_value to be binary. You might want to use to_string/1 or
      inspect/1 to compare other types with File.read!

         assert_value to_string(:foo) == File.read!("foo.log")
         assert_value inspect(:foo) == File.read!("foo.log")
      """
  end

  def check_string_and_file_read(_, _), do: :ok

  defp get_value_type(arg) do
    [{"Data type", type} | _t] = IEx.Info.info(arg)
    type
  end
end
