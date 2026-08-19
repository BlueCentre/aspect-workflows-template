# Application initializer

Repo stamping (`aspect render-preset`) creates a new Bazel monorepo. Application
stamping (`aspect render-app`) creates one application **inside** an existing
monorepo. They are different products; see the design spec in `vitruvian-core`
at `docs/superpowers/specs/2026-08-18-universal-initializer-design.md`.

## Stamping an application

    aspect render-app --language=go --name=payments --out=./app/payments

Optional: `--concerns` (comma-separated; dependencies are added automatically),
`--deploy-target` (`homelab` or `cloudrun`), `--db-provider`, `--http-framework`,
`--module-path`.

`--out` must end in a directory named after the application, and `render-app`
fails if it does not. That is not a style rule — see the next section.

## The gazelle contract

The stamped `BUILD.bazel` has to be **exactly** what gazelle would generate. The
monorepo it lands in already gates on stale BUILD files, so if the stamped file
is not a gazelle fixed point, every stamping PR arrives red no matter how good
the rendering is. The `app-contract` CI job proves the property on every push by
rendering a monorepo, normalizing it, stamping three applications in, running
gazelle, and failing on any diff.

Two of gazelle's Go conventions are properties of the **destination**, not of
the application, so neither can be hard-coded in the template:

- **Target names come from the directory**, verbatim. `app/payments_api` yields
  `payments_api_lib`, `payments_api`, `payments_api_test`. Guessing kebab-case
  there does not merely rename the targets: gazelle adds its own
  `go_library`/`go_test` beside the stamped ones and re-points the `go_binary`,
  leaving two libraries over the same sources. Hence the `--out` basename check.
- **`importpath` is the host module path joined with the package path** relative
  to that module — `example.com/my_project` + `app/payments`. `render-app` reads
  it from the nearest `go.mod` above `--out`; `--module-path` overrides that when
  there is no `go.mod` to read yet.

A third convention is a property of the host's gazelle configuration: the
`go_image` Orion extension (`.aspect/gazelle/go_image.axl`) generates a
`go_image` target for every package containing a `func main`, so the template
ships one. It loads `//bazel/oci:go_image.bzl`, which means the Go application
template currently assumes a host monorepo with the `oci` feature — the same
assumption `--deploy-target` already makes.

**Never silence this check with `# gazelle:ignore`.** `template/hello/go` opts
out deliberately: it is a hand-curated sample. A stamped application is real
code gazelle must manage, and the ignore comment would hide precisely the
breakage the check exists to catch.

## The contract

`template-config.json`'s `app` section declares the languages, concerns and
their `requires` chains, deploy targets and their database providers, and the
presets. Every frontend reads it. Change it and run:

    aspect check-metadata     # the contract is internally consistent
    aspect check-renders      # sampled selections render cleanly

`check-renders` stamps into a scratch directory with no host monorepo above it,
so it supplies `import_path` with the no-host fallback shape. A template that
needs another destination-derived value must be given one there too, or the
smoke passes on output that could never build.

## Adding a language

1. Create `template/app/<language>/`.
2. Add it to `app.languages` with `template_dir` set to `app/<language>`.
3. Add the language to `appliesTo` on each concern it supports.
4. Run both checks; add a preset so the language gets a full build in CI.
5. Extend the `app-contract` job to stamp the new language into a monorepo that
   has it, or the gazelle fixed point goes unproven for that language.

Application templates are excluded from repo stamping by the
`{"flag": "app_template", "globs": ["app/**"]}` rule. That rule is
load-bearing: `is_included` includes any path matched by no rule, so removing
it puts `app/` into all 26 published starter repos.
