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
        # Increase max function arity. We have function with 7 params.
        {Credo.Check.Refactor.FunctionArity, max_arity: 7},
        # Long lines are not ok, Exit with status code
        {Credo.Check.Readability.MaxLineLength, priority: :high,
          max_length: 80, exit_status: 2},
        # Do not suggest to write large numbers with underscore
        # We have GitHub data maps in tests with big ids and bytes sizes
        {Credo.Check.Readability.LargeNumbers, false}
      ]
    }
  ]
}
