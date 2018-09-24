defmodule Studio54.MixProject do
  use Mix.Project

  def project do
    [
      app: :studio54,
      version: "0.4.2",
      description: "SMS sending with HUAWEI E5577Cs-603 LTE modems.  100% test coverage.",
      build_embedded: Mix.env() == :prod,
      package: package(),
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp package do
    # These are the default files included in the package
    [
      name: :studio54,
      files: ["lib", "mix.exs", "README*", "config", "test"],
      maintainers: ["Farsheed Ashouri"],
      licenses: ["Apache 2.0"],
      links: %{"github" => "https://github.com/ourway/studio54"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :timex,
        :poison,
        :elixir_uuid,
        :inets,
        :ssl,
        :mnesia,
        :ibrowse,
        :con_cache,
        :httpotion,
        :exml,
        :persian
      ],
      mod: {Studio54.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:timex, "~> 3.4"},
      {:persian, "~> 0.1.4"},
      {:con_cache, "~> 0.13.0"},
      {:poison, "~> 4.0"},
      {:exml, "~> 0.1.1"},
      {:elixir_uuid, "~> 1.2"},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:httpotion, "~> 3.1"}
    ]
  end
end
