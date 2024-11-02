defmodule StateServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :state_server,
      version: "0.4.10",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      package: [
        description: "half gen_server, half gen_statem, all state machine",
        licenses: ["MIT"],
        files: ~w(lib .formatter.exs mix.exs README* LICENSE* VERSIONS* example),
        links: %{"GitHub" => "https://github.com/ityonemo/state_server"}
      ],
      source_url: "https://github.com/ityonemo/state_server/",
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test],
      docs: [main: "StateServer", extras: ["README.md"]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:multiverses, "~> 0.4", only: :test, runtime: false}
    ]
  end
end
