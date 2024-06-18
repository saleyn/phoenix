for path <- :code.get_path(),
    Regex.match?(~r/phx_new-[\w\.\-]+\/ebin$/, List.to_string(path)) do
  Code.delete_path(path)
end

defmodule Phx.New.MixProject do
  use Mix.Project

  @version "1.7.13"
  @scm_url "https://github.com/phoenixframework/phoenix"

  # If the elixir requirement is updated, we need to update:
  #
  #   1. all mix.exs generated by the installer
  #   2. guides/introduction/installation.md
  #   3. guides/deployment/releases.md
  #   4. test/test_helper.exs at the root
  #   5. installer/lib/mix/tasks/phx.new.ex
  #
  @elixir_requirement "~> 1.14"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env() == :prod,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: [
        maintainers: [
          "Chris McCord",
          "José Valim",
          "Gary Rennie",
          "Jason Stiebs"
        ],
        licenses: ["MIT"],
        links: %{"GitHub" => @scm_url},
        files: ~w(lib templates mix.exs README.md)
      ],
      preferred_cli_env: [docs: :docs],
      source_url: @scm_url,
      docs: docs(),
      homepage_url: "https://www.phoenixframework.org",
      description: """
      Phoenix framework project generator.

      Provides a `mix phx.new` task to bootstrap a new Elixir application
      with Phoenix dependencies.
      """
    ]
  end

  def application do
    [
      extra_applications: [:eex, :crypto]
    ]
  end

  def deps do
    [
      {:ex_doc, "~> 0.24", only: :docs}
    ]
  end

  defp docs do
    [
      source_url_pattern: "#{@scm_url}/blob/v#{@version}/installer/%{path}#L%{line}"
    ]
  end
end
