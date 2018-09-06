defmodule Studio54.MixProject do
  use Mix.Project

  def project do
    [
      app: :studio54,
      version: "0.1.1",
      description: "SMS sending with HUAWEI E5577Cs-603 LTE modems",
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
      links: %{"REPO" => "https://rashavas.visualstudio.com/studio54"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :timex, :inets, :ssl, :ibrowse, :httpotion, :exml],
      mod: {Studio54.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:timex, "~> 3.1"},
      {:exml, "~> 0.1.1"},
      {:httpotion, "~> 3.1"}
    ]
  end
end
