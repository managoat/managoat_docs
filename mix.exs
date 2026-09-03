defmodule Managoat.Docs.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/managoat/managoat_docs"

  def project do
    [
      app: :managoat_docs,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description:
        "A documentation manual embedded at compile time for a Phoenix app to serve, its sanitising markdown renderer, and the guardrail tests that keep it sound.",
      package: package(),
      source_url: @source_url,
      docs: docs(),
      dialyzer: dialyzer(),
      test_coverage: [
        # The compiler, renderer and guardrail checks currently measure
        # 96.93%, driven by the fixture manual and hostile public inputs. The
        # remaining renderer misses are defensive dependency-failure paths;
        # keep a little headroom for a real branch and never lower this gate.
        summary: [threshold: 96],
        # The two `use` macros run at test-compile time, before cover
        # instruments anything, so they always report 0%. They are exercised
        # by the fixture module and by docs_test.exs (and by every host's
        # guardrail file) rather than measured.
        ignore_modules: [Managoat.Docs, Managoat.Docs.GuardrailCase]
      ]
    ]
  end

  # `mix precommit` runs in :test so that its compile, credo and test steps see
  # exactly what CI sees — .github/workflows/ci.yml sets MIX_ENV=test for the
  # whole job. The two steps that must not run there shell out to :dev.
  def cli do
    [preferred_envs: [precommit: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # The fixture manual's docs module lives in test/support: it `use`s the
  # macro against test/fixtures/manual, so it is a test-only compile.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Tooling for the repository, not the package: docs for hexdocs.pm (built
      # by `mix hex.publish`), credo and dialyzer for CI. dialyxir is pinned to
      # the commit that added OTP 28 support; 1.4.7 crashes on OTP 28 warnings.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir,
       github: "jeremyjh/dialyxir",
       ref: "3553678f4d69281ac6db61034bcf35bcb30cfd78",
       only: [:dev, :test],
       runtime: false},
      # comrak, through MDEx. Every page renders through it, both paths.
      {:mdex, "~> 0.13.5"},
      # Syntax highlighting for the trusted path. Called directly rather than
      # through MDEx's integration, which needs a NIF build an order of
      # magnitude larger (147 MB unpacked against 12 MB); see
      # `Managoat.Docs.Markdown`.
      {:lumis, "~> 0.7"},
      # The pre-encoded search index.
      {:jason, "~> 1.2"}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url, "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE NOTICE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      # A fixed path so CI can cache the PLT across runs.
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  # The CI gate, in CI's order, in one command. Keep this and
  # .github/workflows/ci.yml in step: a check that lives only in CI is a check
  # every contributor discovers by pushing.
  defp aliases do
    [
      precommit: [
        &deps_unlock_unused_changes_nothing/1,
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        &dialyzer_in_dev/1,
        "test --cover",
        &hex_build_in_dev/1
      ]
    ]
  end

  # Parity with CI's `mix deps.unlock --unused && git diff --exit-code
  # mix.lock`. A bare "deps.unlock --unused" step rewrites the lockfile and
  # exits 0, so the alias would pass while CI failed the same commit on the
  # diff. Compared against the file as it was a moment ago rather than against
  # git HEAD, so an uncommitted but legitimate lockfile edit (a dependency
  # added on this branch) does not trip it.
  defp deps_unlock_unused_changes_nothing(_args) do
    before = File.read!("mix.lock")
    Mix.Task.run("deps.unlock", ["--unused"])

    if File.read!("mix.lock") != before do
      Mix.raise(
        "mix.lock listed unused dependencies (deps.unlock --unused just pruned them). " <>
          "Commit the updated mix.lock — CI fails this via `git diff --exit-code mix.lock`."
      )
    end

    :ok
  end

  # MIX_ENV=dev on purpose, the same override CI makes: dialyzer analyzes the
  # shipped code, and the test env would drag test-only dependencies into the
  # analysis and into the cached PLT. A function rather than a "cmd ..." step
  # because `mix cmd` execs without a shell and cannot set the environment.
  defp dialyzer_in_dev(_args), do: mix_in_dev(["dialyzer"])

  # What `mix hex.publish` will build, in the environment it builds it in: a
  # dependency hex refuses (a git dep, a path dep) fails here rather than on
  # the PR. The tarball goes to a temporary directory because it is a check,
  # not an artifact, and nothing here should have to gitignore it.
  defp hex_build_in_dev(_args) do
    app = Atom.to_string(Mix.Project.config()[:app])
    mix_in_dev(["hex.build", "--output", Path.join(System.tmp_dir!(), app <> "-precommit.tar")])
  end

  defp mix_in_dev(args) do
    case Mix.shell().cmd(Enum.join(["mix" | args], " "), env: [{"MIX_ENV", "dev"}]) do
      0 -> :ok
      status -> Mix.raise("mix #{Enum.join(args, " ")} failed with exit status #{status}")
    end
  end
end
