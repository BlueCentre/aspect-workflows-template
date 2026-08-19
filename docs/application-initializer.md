# Application initializer

Repo stamping (`aspect render-preset`) creates a new Bazel monorepo. Application
stamping (`aspect render-app`) creates one application **inside** an existing
monorepo. They are different products; see the design spec in `vitruvian-core`
at `docs/superpowers/specs/2026-08-18-universal-initializer-design.md`.

## Stamping an application

    cd <the-monorepo> && aspect render-app --language=go --name=payments --out=./app/payments

Optional: `--concerns` (comma-separated; dependencies are added automatically),
`--deploy-target` (`homelab` or `cloudrun`), `--db-provider`, `--http-framework`.

Two rules `render-app` enforces rather than assumes:

- **`--out` must end in a directory named after the application.** Not a style
  rule — see the next section.
- **`--out` must be inside the target monorepo**, or you must describe that
  monorepo with the flags below. `render-app` reads the destination's `go.mod`;
  it will not invent one. Stamping onto a directory that is *itself* a module
  root is refused, because `--out` is cleared before rendering and that would
  delete the `go.mod` just read.

### Stamping outside the monorepo (the P1 calling convention)

A frontend that renders to a scratch directory and opens a PR against the
monorepo has no `go.mod` to read, so it must supply every destination property
itself. There is deliberately **no default** for any of them — a guessed value
is the exact bug this whole contract exists to prevent, so an unobservable
property is an error, not a fallback:

    aspect render-app --language=go --name=billing \
      --out=/scratch/billing \
      --module-path=example.com/my_project \
      --package-path=services/billing \
      --host-oci=yes

| flag | meaning | default |
|---|---|---|
| `--module-path` | the host monorepo's Go module path | the `module` line of the nearest `go.mod` at or above `--out` |
| `--package-path` | the application's path **relative to that module root** — this is where the PR will put it, which need not match `--out` | `--out`'s path relative to that same `go.mod` |
| `--host-oci` | whether the host ships `bazel/oci/go_image.bzl` and enables the `go_image` gazelle extension | `auto`, which probes the host root |

`--package-path` is not cosmetic: it feeds both `importpath` and the labels in
the generated `README.md`. Passing `--module-path` alone used to leave the
package half at a guessed `app/<name>`; it now fails instead of guessing.

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

A third convention is a property of the host's gazelle **configuration**: the
`go_image` Orion extension (`.aspect/gazelle/go_image.axl`) generates a
`go_image` target for every package containing a `func main` — but only the
presets that ship `bazel/oci/` enable it. So the template emits the target
under `{% if host_oci %}`, and `render-app` resolves `host_oci` by probing the
host root for `bazel/oci/go_image.bzl`.

Getting this wrong is not a local problem. Emitting the target into a host
without `bazel/oci/` produces a `load()` of a file that does not exist, which
fails to load the package and breaks `bazel build //...` for the **entire
repository**, not just the stamped application. The fixed point still holds in
both directions, because a host without the extension never generates a
`go_image` target to begin with. Both hosts are proven in CI: `go` (has oci)
and `copybara-go` (Go, no oci).

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
so it supplies the destination-derived values (`import_path`, `package_path`,
`host_oci`) itself. A template that needs another such value must be given one
there too, or the smoke passes on output that could never build.

It renders every sampled selection **twice**, once per `host_oci` branch, because
the template branches on it and an unrendered branch is an unchecked branch.

Its BUILD.bazel assertion checks for a target *named* after the project
(`name = "<project>`), not merely for the project name appearing somewhere in
the file. The looser form was not a check at all: `importpath` contains the
project name too, so it passed even with every `{{ project_snake }}` in the
template replaced by a literal.

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
