# Changelog

## v0.8.0 - February 1, 2018

 * Upgrade Instructions
   * Run `mix test`. You may get diffs because assert_value no longer converts
     everything to a string
   * Run `ASSERT_VALUE_ACCEPT_DIFFS=reformat mix test` to take advantage of
     improved formatter
 * Feature
   * Support all Elixir types except not serializable (Function, PID,
     Reference, etc.)
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
