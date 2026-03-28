defmodule LanShare.MixProject do
  use Mix.Project

  def project do
    [
      app: :lan_share,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LanShare.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"}
    ]
  end
end
