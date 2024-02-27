defmodule EctoHooks.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :ecto_hooks,
      version: "1.2.0",
      elixir: "~> 1.13",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_file: {:no_warn, "priv/plts/dialyzer.plt"}],
      preferred_cli_env: [
        test: :test,
        "test.watch": :test,
        coveralls: :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls],
      package: package(),
      description: description(),
      source_url: "https://github.com/vereis/ecto_hooks"
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
      # Actual dependencies
      {:ecto_middleware, "~> 1.0"},

      # Lint dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},

      # Test dependencies
      {:ecto, "~> 3.10", only: :test, override: true},
      {:etso, "~> 1.1.0", only: :test},
      {:mix_test_watch, "~> 1.1", only: :test, runtime: false},
      {:excoveralls, "~> 0.16", only: :test, runtime: false},

      # Misc dependencies
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [lint: ["format --check-formatted --dry-run", "credo --strict", "dialyzer"]]
  end

  defp description() do
    """
    Adds callbacks/hooks to Ecto: `after_insert`, `after_update`, `after_delete`,
    `after_get`, `before_insert`, `before_update`, `before_delete`.

    Useful for setting virtual fields and centralising logic.
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/vereis/ecto_hooks"
      }
    ]
  end
end
