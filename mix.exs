defmodule AssertValue.Mixfile do
  use Mix.Project

  def project do
    [
      app: :assert_value,
      version: "0.10.4",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      # Elixir 1.11 checks that all functions used by application belong
      # to modules listed in deps, applications, or extra_applications,
      # and emits warnings on compilation if they not.
      # Since IEx is a part of Elixir and always present we can skip
      # this check and suppress warning about IEx.Info.info/1
      xref: [exclude: [{IEx.Info, :info, 1}]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [],
      mod: {AssertValue.App, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:sourceror, "~> 1.0"}
    ]
  end

  defp description do
    "ExUnit's assert on steroids that writes and updates tests for you"
  end

  defp package do
    [
      files: [
        "lib",
        ".formatter.exs",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      maintainers: ["Gleb Arshinov", "Serge Smetana"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/assert-value/assert_value_elixir",
        "Changelog" =>
          "https://github.com/assert-value/assert_value_elixir/blob/master/CHANGELOG.md"
      }
    ]
  end
end
