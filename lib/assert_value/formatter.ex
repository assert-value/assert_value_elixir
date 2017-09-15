defmodule AssertValue.Formatter do
  @moduledoc false
  use GenServer

  # TODO: Check that user uses default formatter
  defdelegate init(opts), to: ExUnit.CLIFormatter

  # Suppress tests output to stdout on tests run not in --trace mode
  # This is to deal with "." from async tests when waiting for user
  # input for AssertValue.
  # If tests are run with "--trace" then they are not in async mode
  # so we can pass this cast to default formatter
  def handle_cast({:test_finished, %ExUnit.Test{state: nil} = test}, config) do
    if config.trace do
      ExUnit.CLIFormatter.handle_cast({:test_finished, test}, config)
    else
      {:noreply, %{config | test_counter: update_test_counter(config.test_counter, test)}}
    end
  end

  # Handle all other casts from ExUnit.CLIFormatter
  # TODO: Check that user uses default formatter
  defdelegate handle_cast(data, config), to: ExUnit.CLIFormatter

  defp update_test_counter(test_counter, %{tags: %{type: type}}) do
    Map.update(test_counter, type, 1, &(&1 + 1))
  end

end
