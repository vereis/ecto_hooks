defmodule EctoHooks.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :ecto_hooks,
      version: "1.0.4",
      elixir: "~> 1.10",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
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
      # Lint dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},

      # Test dependencies
      {:etso, "~> 1.1.0", only: :test},

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
