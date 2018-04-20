# Changelog

## v0.8.3 - April 20, 2018

 * Bugfixes
   * Fix long (>4096 symbols) binaries serialization
 * Enhancements
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
