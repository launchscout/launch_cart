defmodule LaunchCart.MixProject do
  use Mix.Project

  def project do
    [
      app: :launch_cart,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LaunchCart.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:cachex, "~> 3.4.0"},
      {:cors_plug, "~> 3.0"},
      {:dart_sass, "~> 0.5", runtime: Mix.env() == :dev},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:excessibility, "~> 0.1.0",
       only: [:dev, :test], git: "https://github.com/launchscout/excessibility.git"},
      {:ex_machina, "~> 2.7.0"},
      {:faker, ">= 0.0.0"},
      {:floki, ">= 0.30.0", only: [:dev, :test]},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:live_state, "~> 0.6.0"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.6.12"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:stripity_stripe, "~> 2.17.1"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:wallaby, "~> 0.30.2",
       git: "https://github.com/launchscout/wallaby.git",
       branch: "shadow-dom",
       override: true,
       runtime: false,
       only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.seed": ["run priv/repo/seeds.#{Mix.env()}.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup", "ecto.seed"],
      "ecto.seed_ci": [
        "ecto.drop --no-compile",
        "ecto.setup --no-compile",
        "ecto.seed --no-compile"
      ],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "cmd --cd assets node build.mjs --deploy",
        "phx.digest"
      ]
    ]
  end
end
