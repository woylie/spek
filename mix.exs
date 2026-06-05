defmodule Spek.MixProject do
  use Mix.Project

  @source_url "https://github.com/woylie/spek"
  @version "0.3.1"

  def project do
    [
      app: :spek,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, ".plts/dialyzer.plt"}
      ],
      aliases: aliases(),
      name: "Spek",
      source_url: @source_url,
      homepage_url: @source_url,
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        precommit: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "== 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "== 0.40.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "0.18.5", only: :test}
    ]
  end

  defp description do
    "Boolean expression engine for domain rules"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md",
        "Sponsor" => "https://github.com/sponsors/woylie"
      },
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: @version,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      groups_for_modules: [
        structs: [Spek.AllOf, Spek.Check, Spek.Literal, Spek.Not, Spek.AnyOf]
      ],
      groups_for_docs: [
        "Builder Functions": &(&1[:type] == :builder),
        "Evaluation Functions": &(&1[:type] == :evaluation),
        "Optimization Functions": &(&1[:type] == :optimization)
      ],
      groups_for_extras: [
        Cheatsheets: ~r/cheatsheets\/.?/
      ]
    ]
  end

  def aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "format",
        "credo",
        "coveralls --warnings-as-errors",
        "dialyzer",
        "docs --warnings-as-errors"
      ]
    ]
  end
end
