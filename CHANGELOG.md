# Changelog
## v0.9.5 - October 27, 2020

 * Enhancements
   * Do not run :iex app when running tests.
     Add "xref: [exclude: [{IEx.Info, :info, 1}]]" to project
     to avoid compilation warning

## v0.9.4 - October 22, 2020

 * Enhancements
   * Fix deprecation warnings in Elixir 1.10 and 1.11

# Changelog
## v0.9.3 - June 12, 2019

 * Enhancements
   * Fix deprecation warnings in Elixir 1.8

## v0.9.2 - May 29, 2018

 * Bugfixes
   * Fix big data structure serialization using plain Macro.to_string()
     when running Elixir >= 1.6.5

## v0.9.1 - May 18, 2018

 * Bugfixes
   * Include .formatter.exs in the hex package

## v0.9.0 - May 10, 2018

 * Features
   * assert_value now uses Elixir Formatter to format values. This improves
     formatting of big data structures. Previously assert_value formatted
     expected values other than strings as one line making code unreadable
     when using big data structures like long arrays and nested maps. Now
     we use Elixir Formatter and it formats them correctly on multiple lines
 * Enhancements
   * assert_value now shows easier to understand diffs (more context)
     ```
     # assert_value v0.8.5
     test/example_test.exs:7:"test expected" assert_value 2 + 2 failed
     -
     +4

     # assert_value v0.9.0
     test/example_test.exs:7:"test example" assert_value failed
     -    assert_value 2 + 2
     +    assert_value 2 + 2 == 4
     ```
 * Requirements
   * Elixir >= 1.6
 * Upgrade Instructions
   * Add this to .formatter.exs:
     ```elixir
     [
       # don't add parens around assert_value arguments
       import_deps: [:assert_value],
       # use this line length when updating expected value
       line_length: 98 # whatever you prefer, default is 98
     ]
     ```
   * Run `ASSERT_VALUE_ACCEPT_DIFFS=reformat mix test` to take advantage of
     improved formatter

## v0.8.5 - April 30, 2018

 * Enhancements
   * Better error messages and README.md

## v0.8.4 - April 20, 2018

 * Features
   * Remove support for strict equality (===)

## v0.8.3 - April 20, 2018

 * Bugfixes
   * Fix long (>4096 symbols) binaries serialization
 * Features
   * Support strict equality operator: `assert_value 1 === 1.0`

## v0.8.2 - February 19, 2018

 * Bugfixes
   * Fix parser to correctly parse calls to functions without arguments
 * Enhancements
   * Better check and error message for not-serializable values

## v0.8.1 - February 8, 2018

 * Bugfixes
   * Fix parser for code producing AST with hygienic counters

## v0.8.0 - February 1, 2018

 * Upgrade Instructions
   * Run `mix test`. You may get diffs because assert_value no longer converts
     everything to a string
   * Run `ASSERT_VALUE_ACCEPT_DIFFS=reformat mix test` to take advantage of
     improved formatter
   * Add this to .formatter.exs to make Elixir formatter not to add parens to
     assert_value
     ```elixir
     [
       import_deps: [:assert_value]
     ]
     ```
 * Features
   * Support all argument types (e.g. Integer, List, Map) except not
     serializable (e.g. Function, PID, Reference)
   * Add ASSERT_VALUE_ACCEPT_DIFFS=reformat to automatically reformat all
     expected values
 * Enhancements
   * Better parser now supports any kind of formatting (expressions,
     parentheses, multi-line, etc.)
   * Better formatter (smarter formatting one-line and multi-line strings)
   * Better error reporting
   * Ensure compatibility with Elixir 1.6

## v0.7.1 - October 27, 2017

 * Enhancements
   * Better prompt (less options displayed for better readability)
   * Better README.md

## v0.7.0 - October 13, 2017

 * Initial release
