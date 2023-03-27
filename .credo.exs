# Credo config to add/disable check rules.
# On execution it is merged with default config in deps/credo/.config.exs
%{
  configs: [
    %{
      # All configs are named to be executed with 'mix credo -C <name>'
      # To merge with default config we should specify "default" name
      name: "default",
      strict: true,
      color: true,
      #
      # These are the files included in the analysis
      # We SHOULD specify them here
      # This key IS NOT merged with default config
      files: %{
        included: ["lib/", "config/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      requires: [],
      #
      # This key IS merged with default config
      # Add here only changes to default rules
      checks: [
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Refactor.PipeChainStart, false},
        {Credo.Check.Design.TagTODO, false},
        # Turn off function complexity check. It always fail on
        # assert_value macro because it is complex.
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        # Same for function body nesting
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Refactor.FunctionArity, false},
        # Long lines are not ok, Exit with status code
        {Credo.Check.Readability.MaxLineLength,
         ignore_strings: false,
         ignore_definitions: false,
         priority: :high,
         exit_status: 2},
        # Do not suggest to write large numbers with underscore
        # We have GitHub data maps in tests with big ids and bytes sizes
        {Credo.Check.Readability.LargeNumbers, false},
        # We have a lot of assert_value "foo" == "foo" in tests
        {Credo.Check.Warning.OperationOnSameValues, false}
      ]
    }
  ]
}
