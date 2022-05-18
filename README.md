# assert_value for Elixir
[![Build Status](https://travis-ci.org/assert-value/assert_value_elixir.svg?branch=master)](https://travis-ci.org/assert-value/assert_value_elixir)
[![Hex Version](https://img.shields.io/hexpm/v/assert_value.svg)](https://hex.pm/packages/assert_value)

`assert_value` is ExUnit's `assert` on steroids. It writes and updates tests for you.

  * `assert_value` allows you not to think about the correct expected values when writing
    tests
  * Gets rid of manual tests maintenance
  * Makes Elixir tests interactive and lets you to create and update expected values
    with a single key press
  * Improves test readability

## Screencast

![Screencast](https://github.com/assert-value/assert_value_screencasts/raw/master/elixir-0.9.0/screencast.gif)

## Usage

```elixir
assert_value :foo

assert_value 2 + 2 == 4

assert_value "foo" == File.read!("test/log/foo.log")
```

You can use `assert_value` instead of ExUnit's `assert`. When writing a new test
you don't have to enter expected value. When you run it the first time `assert_value`
will generate it, show it to you, and will automatically update test source if
you accept it.

When you run an existing test and the actual value does not match expected,
`assert_value` will show the diff and ask you what to do. You then tell it
if the new actual value is correct. If it is, `assert_value` will update the test
source code with it. If not `assert_value` will fail the test just like builtin `assert`.

`assert_value` also lets you store expected value in a separate file using File.read!
This makes sense for longer values. `assert_value` will create and update file contents.

## Requirements

Elixir ~> 1.7

## Installation

Add this to mix.exs:

```elixir
defp deps do
  [
    {:assert_value, ">= 0.0.0", only: [:dev, :test]}
  ]
end
```
Add this to config/test.exs to avoid timeouts:

```elixir
# Avoid timeouts while waiting for user input in assert_value
config :ex_unit, timeout: :infinity
config :my_app, MyApp.Repo,
  timeout: :infinity,
  ownership_timeout: :infinity
```

Add this to .formatter.exs:
```elixir
[
  # don't add parens around assert_value arguments
  import_deps: [:assert_value],
  # use this line length when updating expected value
  line_length: 98 # whatever you prefer, default is 98
]

```

## HOWTO

Tests are code. They should be readable, maintainable, and reusable.
Tests should break when behaviour changes and should not break randomly.
We will look at how to do this in Elixir project.

### Traditional Way

Let's create a new Phoenix project:

```bash
mix phx.new example --no-brunch --no-ecto
```
This generates a controller test:

```elixir
defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
```
Now we want to add tests for page content. Traditional way to to it looks
like this:
```elixir
# Use Floki to parse html
# mix.exs
  defp deps do
    [
      {:floki, "~> 0.7", only: :test}
    ]
  end

# test/example_web/controllers/page_controller_test.exs
defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200)
    body = html_response(conn, 200)
    title = Floki.find(body, "title")
      |> Floki.text
    assert title == "Hello Example!"
    header = Floki.find(body, "h2")
      |> Floki.text
    assert header == "Welcome to Phoenix!"
    sections = Floki.find(body, "h4")
      |> Enum.map(&Floki.text/1)
    assert sections == ["Resources", "Help"]
  end
end
```
Why is this bad?
  * It is hard to read
  * You have a lot of code duplication when testing multiple pages
  * It makes it expensive to create new tests and even more expensive
    to update them
  * This will hurt tests coverage and will make it more expensive to
    create new features or refactor code

Let's fix this.

### Serialization

We will write a serialization function that extracts
parts of the page and presents them in a human readable format:

```elixir
# Add assert_value to mix.exs
  defp deps do
    [
      {:floki, "~> 0.7", only: :test},
      {:assert_value, ">= 0.0.0", only: [:dev, :test]}
    ]
  end


# test/example_web/controllers/page_controller_test.exs
defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase
  import AssertValue

  defp serialize_response(conn) do
    %Plug.Conn{status: status, resp_body: body} = conn
    "Status: #{status}" <>
    "\nTitle: " <>
    (body
      |> Floki.find("title")
      |> Floki.text) <>
    "\n" <>
    (body
      |> Floki.find("h1,h2,h3,h4")
      |> Enum.map(fn({tagName, _attrs, content}) ->
          "#{tagName}: #{Floki.text(content)}"
         end)
      |> Enum.join("\n")) <>
    "\n"
  end

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert_value serialize_response(conn)
  end
end
```
Note, we don't need to specify expected value when writing the test.
`assert_value` will generate it, show it to us, and will automatically
update test source if we accept it.

```diff
~/> mix test
...
test/example_web/controllers/page_controller_test.exs:23:"test GET /" assert_value serialize_response(conn) failed

-
+Status: 200
+Title: Hello Example!
+h2: Welcome to Phoenix!
+h4: Resources
+h4: Help

Accept new value? [y,n,?] y
.

Finished in 1.5 seconds
4 tests, 0 failures
```

```elixir
  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert_value serialize_response(conn) == """
    Status: 200
    Title: Hello Example!
    h2: Welcome to Phoenix!
    h4: Resources
    h4: Help
    """
  end
```

And in the future when you update your page content all you need to do
is accept new diff to update the test.

### Reuse

The best part of using serializers is that you can reuse them.
Let's add one more page to our sample app:

```elixir
# lib/example_web/controllers/page_controller.ex
defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def hello(conn, _params) do
    render conn, "hello.html"
  end
end

# lib/example_web/templates/page/hello.html.eex
<h2>Hello World</h2>

# Add route to lib/example_web/router.ex
  scope "/", ExampleWeb do
    pipe_through :browser # Use the default browser stack
    get "/", PageController, :index
    get "/hello", PageController, :hello
  end
```

Now it is easy to add a new test
```elixir
  # test/example_web/controllers/page_controller_test.exs
  test "GET /hello", %{conn: conn} do
    conn = get conn, "/hello"
    assert_value serialize_response(conn)
  end
```
And run tests
```diff
~> mix test
....
test/example_web/controllers/page_controller_test.exs:34:"test GET /hello" assert_value serialize_response(conn) failed

-
+Status: 200
+Title: Hello Example!
+h2: Hello World

Accept new value? [y,n,?] y
.

Finished in 1.9 seconds
5 tests, 0 failures
..

Finished in 8.8 sec
```
And your tests are automatically updated
```elixir
  test "GET /hello", %{conn: conn} do
    conn = get conn, "/hello"
    assert_value serialize_response(conn) == """
    Status: 200
    Title: Hello Example!
    h2: Hello World
    """
  end
```

### Easy Refactoring

Now let's say you change the title in the layout.

```diff
diff --git a/lib/example_web/templates/layout/app.html.eex b/lib/example_web/templates/layout/app.html.eex
index f10cd22..b70a0ae 100644
--- a/lib/example_web/templates/layout/app.html.eex
+++ b/lib/example_web/templates/layout/app.html.eex
@@ -7,7 +7,7 @@
     <meta name="description" content="">
     <meta name="author" content="">

-    <title>Hello Example!</title>
+    <title>My App Example!</title>
     <link rel="stylesheet" href="<%= static_path(@conn, "/css/app.css") %>">
   </head>
```

Without `assert_value` you would have had to manually update all tests.
With assert_value all you need is to accept new diffs:

```diff
~> mix test
...
test/example_web/controllers/page_controller_test.exs:23:"test GET /" assert_value serialize_response(conn) == "Status: 200... failed

 Status: 200
-Title: Hello Example!
+Title: My App Example!
 h2: Welcome to Phoenix!
 h4: Resources
 h4: Help

Accept new value [y/n/Y/N/d/?]? y
.
test/example_web/controllers/page_controller_test.exs:34:"test GET /hello" assert_value serialize_response(conn) == "Status: 200... failed

 Status: 200
-Title: Hello Example!
+Title: My App Example!
 h2: Hello World

Accept new value [y/n/Y/N/d/?]? y
.

Finished in 4.3 seconds
5 tests, 0 failures
```

Combining serialization and assert_value makes it easy to write and _maintain_
tests. Especially when your software is changing fast.

### Canonicalization

A common problem with testing serialized output that it may contain unpredictable
or changing data (like tokens, timestamps, ids, etc). The solution for this problem
is canonicalization.

Let's add timestamps to all our pages:
```diff
--- a/lib/example_web/templates/layout/app.html.eex
+++ b/lib/example_web/templates/layout/app.html.eex
@@ -28,6 +28,7 @@
       <main role="main">
         <%= render @view_module, @view_template, assigns %>
       </main>
+      <h4>Created: <%= DateTime.utc_now |> to_string %></h4>

     </div> <!-- /container -->
     <script src="<%= static_path(@conn, "/js/app.js") %>"></script>
```

No when you run `mix test` you will always get diffs
```diff
test/example_web/controllers/page_controller_test.exs:35:"test GET /hello" assert_value serialize_response(conn) == "Status: 200... failed

 Status: 200
 Title: My App Example!
 h2: Hello World
-h4: Created: 2017-10-25 12:35:23.144635Z
+h4: Created: 2017-10-25 12:35:24.268836Z

Accept new value? [y,n,?] n
```

To fix this we will add canonicalization to the serializer
```elixir
  defp serialize_response(conn) do
    %Plug.Conn{status: status, resp_body: body} = conn
    "Status: #{status}" <>
    "\nTitle: " <>
    (body
      |> Floki.find("title")
      |> Floki.text) <>
    "\n" <>
    (body
      |> Floki.find("h1,h2,h3,h4")
      |> Enum.map(fn({tagName, _attrs, content}) ->
          "#{tagName}: #{Floki.text(content)}"
         end)
      |> Enum.join("\n")) <>
    "\n"
    |> canonicalize_response
  end

  defp canonicalize_response(text) do
    text
    |> String.replace(~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+Z/, "<TIMESTAMP>")
  end
```
Then you just need to run `mix test` and accept the diffs
```diff
~/> mix test
...
test/example_web/controllers/page_controller_test.exs:30:"test GET /" assert_value serialize_response(conn) == "Status: 200... failed

 Status: 200
 Title: My App Example!
 h2: Welcome to Phoenix!
 h4: Resources
 h4: Help
-h4: Created: 2017-10-25 12:35:25.268836Z
+h4: Created: <TIMESTAMP>

Accept new value? [y,n,?] y
.
test/example_web/controllers/page_controller_test.exs:41:"test GET /hello" assert_value serialize_response(conn) == "Status: 200... failed

 Status: 200
 Title: My App Example!
 h2: Hello World
-h4: Created: 2017-10-25 12:35:25.936541Z
+h4: Created: <TIMESTAMP>

Accept new value? [y,n,?] y
.

Finished in 10.0 seconds
5 tests, 0 failure
```

## API

### No Expected Value

It is better to start with no expected value

```elixir
assert_value "foo"
```
When you run it the first time `assert_value` will generate it, show it to us,
and will automatically update test source if we accept it.

### Expected Value in the Source Code

```elixir
assert_value 2 + 2 == 4
```
`assert_value` will update expected values for you in the source code.
`assert_value` supports all Elixir types except not serializable (Function,
PID, Port, Reference).

When expected is a multi-line string `assert_value` will format it as a heredoc
for better code diff readability. Heredocs in Elixir always end with a newline
character. When expected value does not end with a newline `assert_value` will
append a special ```<NOEOL>``` string to indicate that last newline should be
ignored.

### Expected Value in a File

Sometimes test values are too large to be inlined into the test source.
Put them into the file instead.

```elixir
assert_value "foo" == File.read!("test/log/reference.txt")
```
assert_value is smart enough to recognize File.read! and will update file contents
instead of test source. If file does not exists it will be created and no error
will be raised despite default File.read! behaviour.

### Running Tests Interactively

assert_value will autodetect whether it is running interactively (in a
terminal), or non-interactively (e.g. continuous integration).
When running interactively it will ask about each diff.

You can accept or reject new value with ```y``` or ```n```. If you use ```Y```
and ```N``` (uppercase) assert_value will remember the answer and will not ask
again during this test run. ```?``` will show help with all available actions.
```
Accept new value? [y,n,?] ?

    y - Accept new value as correct. Will update expected value. Test will pass
    n - Reject new value. Test will fail
    Y - Accept all. Will accept this and all following new values in this run
    N - Reject all. Will reject this and all following new values in this run
    d - Show diff between actual and expected values
    ? - This help

```

### Running Tests Non-interactively

When running non-interactively assert_value will reject all diffs by default, and will
work like default ExUnit's assert.

To override autodetection use ASSERT_VALUE_ACCEPT_DIFFS environment variable
with one of three values: "ask", "y", "n"
```
# Ask about each diff. Useful to force interactive behavior despite
# autodetection.
ASSERT_VALUE_ACCEPT_DIFFS=ask mix test

# Reject all diffs. Useful to force default non-interactive mode when running
# in an interactive terminal.
ASSERT_VALUE_ACCEPT_DIFFS=n mix test

# Accept all diffs. Useful to update all expected values after a refactoring.
ASSERT_VALUE_ACCEPT_DIFFS=y mix test

# Automatically reformat all expected values. Useful to reformat all tests
# when a new assert_value version improves formatter.
ASSERT_VALUE_ACCEPT_DIFFS=reformat mix test
```

## Notes and Known Issues

  * assert_value supports all Elixir types except not serializable (Function,
    PID, Port, Reference). To compare values of theese types use ```inspect```
    and [Serialization](#serialization) techniques.
  * assert_value's formatter is primitive and does not understand operator
    precedence. When creating a new expected value from scratch it simply
    appends "== <expected_value>" to the expression. This usually works but can
    produce incorrect source code in unusual cases. For example
    `assert_value foo = 1` will become `assert_value foo = 1 == 1` instead of
    `assert_value (foo = 1) == 1`.  To workaround this wrap actual expression
    in parentheses.  In practice you are unlikely to run into this problem.
  * assert_value works only with the default ExUnit formatter (ExUnit.CLIFormatter).
    Chances are that it is what you are using.

## Contributing

We appreciate any contribution to assert_value

To file a bug report create a [GitHub issue](https://github.com/assert-value/assert_value_elixir/issues).

To create a feature requests add a comment to the [Roadmap](https://github.com/assert-value/assert_value_elixir/issues/1)

To make a pull request:

  * Fork https://github.com/assert-value/assert_value_elixir and clone your fork
  * Create a new topic branch (off of master) to contain your feature, change, or fix.
    `git checkout -b my-feature`
  * Make sure to add tests for your code
  * Run `mix test`. Make sure all the tests are still passing.
  * Run `mix credo` to make sure your code is following our code guidelines.
  * Commit your changes. Keep your commit messages organized, with a short description
    in the first line and more detailed information on the following lines.
  * Check TravisCI build on your repository
  * Open a pull request

## License

This software is licensed under [the MIT license](LICENSE).
