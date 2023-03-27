[
  inputs: ["*.exs", "lib/**/*.ex"],
  line_length: 80,
  locals_without_parens: [assert_value: :*],
  export: [
    locals_without_parens: [assert_value: :*]
  ]
]
