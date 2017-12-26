defmodule AssertValue.ParserTest do
  use ExUnit.Case

  import AssertValue.Server, only: [parse_statement: 4]

  test "simple" do
    # assert_value "foo" == "bar"
    line = "    assert_value \"foo\" == \"bar\""
    assert parse_statement(line, "", "\"foo\"", "\"bar\"") ==  {"    ", "assert_value \"foo\" == ", "\"bar\"", "\n"}
  end

  test "parenthesis" do
    # assert_value("foo" == "bar")
    line = "    assert_value(\"foo\" == \"bar\")"
    assert parse_statement(line, "", "\"foo\"", "\"bar\"") == {"    ", "assert_value(\"foo\" == ", "\"bar\"", ")\n"}
  end

  test "parenthesis and newlines" do
    # assert_value (
    #   "bar=="
    #   <> "baz" ==
    #   "baz==" <> "foo"
    # )
    line = "    assert_value ("
    suffix = "      \"bar==\"\n      <> \"baz\" ==\n      \"baz==\" <> \"foo\"\n    )\n"
    assert parse_statement(line, suffix, "\"bar==\" <> \"baz\"", "\"baz==\" <> \"foo\"") ==
      {"    ", "assert_value (\n      \"bar==\"\n      <> \"baz\" ==\n      ", "\"baz==\" <> \"foo\"", "\n    )\n"}
  end

  test "operator on a new line" do
    # assert_value("foo"
    # == "bar")
    line = "    assert_value(\"foo\""
    suffix = "    == \"bar\")\n"
    assert parse_statement(line, suffix, "\"foo\"", "\"bar\"") == {"    ", "assert_value(\"foo\"\n    == ", "\"bar\"", ")\n"}
  end

end
