# Application initializer

Repo stamping (`aspect render-preset`) creates a new Bazel monorepo. Application
stamping (`aspect render-app`) creates one application **inside** an existing
monorepo. They are different products; see the design spec in `vitruvian-core`
at `docs/superpowers/specs/2026-08-18-universal-initializer-design.md`.

**The initializer ships inside every repo it serves.** It is authored here, in
`template/tools/initializer/`, and delivered verbatim by repo stamping, so a
monorepo rendered from any preset arrives with `tools/initializer/` and a
`MODULE.aspect` that registers `render-app`, `check-metadata` and
`check-renders` as real `aspect` commands in that repo. Nothing at stamping time
reaches back to `aspect-workflows-template` — it does not have to exist, be
reachable, or be version-compatible (ADR-026).

## Stamping an application

From the root of the monorepo you are stamping into, using **that repo's own**
initializer:

    cd <the-monorepo>
    aspect render-app --language=go --name=payments --out=./app/payments

Optional: `--concerns` (comma-separated; dependencies are added automatically),
`--deploy-target` (`homelab` or `cloudrun`), `--db-provider`, `--http-framework`.

**Run it from the repo root — this is a requirement, not just how the example
above happens to `cd`.** `_base(ctx)` locates the engine by probing
`ctx.std.env.current_dir()` for `template/tools/initializer` or
`tools/initializer`; from any other directory neither exists there and
`render-app` fails with "Run this from the repo root," not a guess at the
correct tree.

The same repo also carries the contract checks, for anyone extending its copy of
the engine:

    aspect check-metadata     # the contract is internally consistent
    aspect check-renders      # sampled selections render cleanly

> **`--out` is CLEARED IF IT EXISTS.** `render-app` deletes the directory
> recursively and recreates it before rendering, exactly like `render-preset`.
> Point it at the application's own directory and nothing else. Every spelling
> of the path is normalized first, so `--out=X`, `--out=X/`, and `--out=X/.`
> all name — and all clear — the same directory. A frontend must never pass a
> directory it does not own the entire contents of.

Two rules `render-app` enforces rather than assumes:

- **`--out` must end in a directory named after the application.** Not a style
  rule — see [the gazelle contract](#the-gazelle-contract).
- **`--out` must be inside the target monorepo**, or you must describe that
  monorepo with the flags below. `render-app` reads the destination's `go.mod`
  and its root build file; it will not invent either. Stamping onto a directory
  that is *itself* a module root is refused, because `--out` is cleared before
  rendering and that would delete the `go.mod` just read. The refusal compares normalized path
  *segments*, so no spelling of the module root (`<root>/`, `<root>/.`,
  `<root>/x/..`) can slip past it; CI proves all of them, and proves the host
  survives the refusal.

### Stamping outside the monorepo (the P1 calling convention)

A frontend — the Backstage Create page, the P4 service, `devx app new` — does
**not** ship an engine of its own. It **clones the target repository and runs
that repository's `aspect render-app`**, which is why the engine is embedded at
all: the code that stamps an application is always the same vintage as the repo
being stamped, so a frontend can serve repos of many different vintages without
a compatibility matrix.

When the frontend renders into a scratch directory to open a PR with, rather
than into the checkout itself, there is no `go.mod` above `--out`, so it must
supply every destination property itself. There is deliberately **no default**
for any of them — a guessed value is the exact bug this whole contract exists to
prevent, so an unobservable property is an error, not a fallback:

    cd <clone-of-the-target-monorepo>
    aspect render-app --language=go --name=billing \
      --out=/scratch/billing \
      --module-path=example.com/my_project \
      --package-path=services/billing \
      --host-oci=yes

Note where the command runs: **inside the clone** (that is where an engine
exists at all — outside a repo carrying `tools/initializer/` there is none to
run) while `--out` points outside it.

**"Does this repo have an engine?"** is a question a frontend must answer
*before* cloning-and-running, e.g. to decide whether to offer app stamping at
all. The concrete predicate: `tools/initializer/config.json` exists **and**
`MODULE.aspect` registers all three tasks (`render_app`, `check_metadata`,
`check_renders`) via `use_task("tools/initializer/tasks.axl", ...)`. Either
alone is not enough — a repo mid-migration could carry one without the other.

| flag | meaning | default |
|---|---|---|
| `--module-path` | the Go import prefix the stamped package's `importpath` is built from | the host's root `# gazelle:prefix`, else the `module` line of the nearest `go.mod` at or above `--out` (see below) |
| `--package-path` | the application's path **relative to that module root** — this is where the PR will put it, which need not match `--out` | `--out`'s path relative to that same `go.mod` |
| `--host-oci` | whether the host ships `bazel/oci/go_image.bzl` and enables the `go_image` gazelle extension | `auto`, which probes the host root |

Two further destination properties have **no flag at all** — they are read off
the host's root build file (`BUILD.bazel`, else `BUILD`), the same way
`--host-oci=auto` probes for `bazel/oci/go_image.bzl` and `--module-path` reads
`go.mod`. Absent, both fall back to gazelle's own defaults, which is why every
starter renders exactly as it did before they existed:

| directive in the host's root build file | what it changes | absent |
|---|---|---|
| `# gazelle:build_file_name <names>` | the name the app's build file is written under — the **first** name on the list, because that is the one gazelle creates a new package's build file with | `BUILD.bazel` |
| `# gazelle:prefix <prefix>` | the Go import prefix `importpath` is built from | the `module` line of the nearest `go.mod` at or above `--out` |

The design rule for both — and the one to apply to any future host convention —
is **mirror gazelle's own precedence**. `# gazelle:prefix` outranks the `go.mod`
module path *in gazelle*, so it outranks it here; an explicit `--module-path`
outranks both, because it is the operator saying the host on disk is not the
destination. Whatever gazelle would do to the stamped package is what the engine
must emit, since gazelle gets the last word the moment the stamping PR lands.

#### Where "root" means, and what is not covered

**"Root" is the Go module root** — the directory whose `go.mod` the walk up from
`--out` stopped at — **not the repository root.** They are the same directory in
every preset and in every host seen so far, but they need not be: a repo that
keeps its `go.mod` in a subdirectory has its directives in a root build file the
probe never reaches, and silently gets the pre-directive behaviour. That is
deliberate, not an oversight — `prefix` and `--package-path` are both expressed
relative to the module root, so anchoring them anywhere else would make the two
halves of `importpath` disagree. Pass `--module-path` on such a host.

Only that **one** build file is read. gazelle inherits directives down the tree
and a subdirectory may override either one; reading the whole chain would mean
reimplementing gazelle's configuration walk inside a template engine. The root
is where a monorepo declares repo-wide conventions, and `--module-path` covers
the rest — a narrower answer than gazelle's, never a different one.

**`build_file_name` has no flag override.** `--module-path` can force the prefix
half, but nothing forces the file name; a host that needs a name other than what
its root directive says has to change the directive. Which also means that on a
host with directives, `--module-path` yields a **mixed-source** result — prefix
from the flag, file name from the host. That is the intended reading of "the
flag says the host on disk is not the destination *for the import prefix*", but
it is worth knowing when a stamped file lands under an unexpected name.

A collision between `build_file_name` and a file the app template renders (say
`# gazelle:build_file_name README.md`) is **refused**, not silently resolved:
renaming onto it would destroy the template's file, and only a human can decide
which of the two should move.

#### Known divergences from gazelle's own parser

The directive matcher reproduces gazelle's `^#\s*gazelle:(\w+)\s*(.*?)\s*$` —
`#gazelle:prefix x`, `#   gazelle:prefix x` and a tab between keyword and value
are all honoured, and `## gazelle:prefix x` is correctly *not* a directive.
Repeats are last-wins, as in gazelle. Three differences remain, all deliberate:

- **String literals.** gazelle matches against parsed comment *tokens*; this
  matches raw lines, so a directive-shaped line inside a `"""..."""` literal is
  honoured here and ignored by gazelle. Closing it means parsing Starlark inside
  a template engine, and being wrong costs one gazelle rewrite — visible and
  trivially fixed.
- **Empty values.** gazelle treats `# gazelle:prefix` with no value as *unsetting*
  the directive; here it is ignored, so an earlier non-empty value still stands.
- **WORKSPACE-era prefix *rules*.** Before falling back to `go.mod`, gazelle also
  consults the legacy `go_prefix("...")` rule and a `gazelle(prefix = "...")`
  rule in the root build file. (There is no `# gazelle:go_prefix` *directive* —
  the prefix has only ever been a directive under the name `prefix`.) Those are
  rules, not comments, so reading them means parsing Starlark; a host still
  declaring its prefix that way silently gets the `go.mod` fallback. Pass
  `--module-path` on such a host.

`--package-path` is not cosmetic: it feeds both `importpath` and the labels in
the generated `README.md`. **`--module-path` and `--package-path` come as a
pair when there is no host on disk.** Passing `--module-path` alone used to
leave the package half at a guessed `app/<name>`; it now *fails* instead of
guessing — with no `go.mod` above `--out` there is nothing to derive the
package path from, so `--module-path` without `--package-path` is an error, not
a partial override. (Inside a monorepo either flag may be passed alone: the
`go.mod` supplies whichever half you omit.)

The `app-contract` CI job renders exactly the invocation above — from inside a
rendered starter, to an `--out` outside it — and asserts both properties the
flags exist to control: that `importpath` is the module path joined with the
package path, and that `--host-oci=no` emits no `go_image`.

## Where the engine lives (two mount points)

One source tree, delivered to a second location. Every path in `tasks.axl` hangs
off `_base(ctx)`, which *probes* for the two and refuses to guess:

| | path | what it is |
|---|---|---|
| authoring | `aspect-workflows-template/template/tools/initializer/` | the **development mount**. Under `template/`, because that is what repo stamping renders. |
| consumption | `<any stamped repo>/tools/initializer/` | the **product**. `template/` is not part of a starter; the tree below it *is* the starter. |

Both present, or neither present, is an error rather than a preference — there
is no defensible tie-break, and getting it wrong would be silent (`render-app`
would happily render whichever tree it found).

The engine tree is listed in `template-config.json`'s `no_render`, so repo
stamping copies it **verbatim** — the jinja inside it is the application
templates' own, and must survive to be rendered later by `render-app`. Same for
`MODULE.aspect`.

### The `.tmpl` suffix

Application templates are named `BUILD.bazel.tmpl`, `main.go.tmpl`,
`catalog-info.yaml.tmpl`, … and the renderer strips the suffix on output (the
contract's `template_suffix` key; `render.axl:_output_rel`).

**Why:** a template tree that ships inside a *live repo* cannot name its files
after its output. A jinja file called `BUILD.bazel` is claimed there by bazel,
buildifier, gofmt and Backstage discovery. `.bazelignore` (shipped by *repo
stamping*, from `template/.bazelignore` -- not part of the engine tree) fixes
bazel and gazelle — but buildifier walks the *filesystem* and does
not read `.bazelignore`, so `aspect buildifier` in a starter parses the jinja and
exits 1 no matter what is ignored. (The starter's own CI runs it with no
`--scope`; the default `--scope=changed` degrades to a whole-tree walk whenever
it cannot resolve a merge base, which is exactly the state of a freshly
delivered starter.) The only remedy that covers every such tool is
a name none of them claims. It also generalizes: `gofmt` is inert on today's
`main.go` only because its placeholders sit in a comment and a string literal,
and the first concern that adds a `{% if %}` would break that.

**Consequence for the contract:** globs in `config.json` (`rules`, `no_render`,
`executable`) match **output** names, not the on-disk template names — the suffix
is stripped before matching. Write `BUILD.bazel`, never `BUILD.bazel.tmpl`.
`check-renders` asserts both halves: that no output still carries the suffix, and
that the rendered name set is exactly what `_EXPECTED_OUTPUTS` in `tasks.axl`
pins for that language.

### The snapshot trade

An embedded engine is a **snapshot**. A repo stamped today keeps the engine it
was born with; a fix landed here does not travel back to it.

- Our 26 published starter repos *do* refresh: `deliver.yaml` re-renders every
  preset from `template/` on each push to `platform-v2.0` and force-pushes the
  result, so the starters always carry the current engine.
- Repos created *from* a starter keep their snapshot until someone updates it
  deliberately. That is the price of the property that buys everything else:
  stamping never depends on a network, a service, or this repo's availability,
  and the engine version always matches the repo it is stamping into.

## The gazelle contract

The stamped `BUILD.bazel` has to be **exactly** what gazelle would generate. The
monorepo it lands in already gates on stale BUILD files, so if the stamped file
is not a gazelle fixed point, every stamping PR arrives red no matter how good
the rendering is. The `app-contract` CI job proves the property on every push by
rendering a monorepo, normalizing it, stamping three applications in **with that
rendered repo's own embedded engine**, running gazelle, and failing on any diff
— and it does that for **each of two hosts** (`go` and `copybara-go`), so six
stampings are checked in all.

Three of gazelle's Go conventions are properties of the **destination**, not of
the application, so none of them can be hard-coded in the template:

- **Target names come from the directory**, verbatim. `app/payments_api` yields
  `payments_api_lib`, `payments_api`, `payments_api_test`. Guessing kebab-case
  there does not merely rename the targets: gazelle adds its own
  `go_library`/`go_test` beside the stamped ones and re-points the `go_binary`,
  leaving two libraries over the same sources. Hence the `--out` basename check.
- **`importpath` is the host's import prefix joined with the package path**
  relative to the module root — `example.com/my_project` + `app/payments`.
  `render-app` takes the prefix from the host's root `# gazelle:prefix` if it
  declares one, else from the nearest `go.mod` above `--out`; `--module-path`
  overrides both.
- **The build file's NAME is the host's**, from its root
  `# gazelle:build_file_name`. gazelle only *reads* a build file whose name is on
  that list, so a host that declares `BUILD` does not see a stamped `BUILD.bazel`
  at all: it writes a second, competing `BUILD` beside it, leaving two build
  files over one package and a permanently dirty tree that the host's
  stale-BUILD gate fails on forever.

Neither of the last two can be observed from a starter this repo renders — every
preset leaves `build_file_name` unset and renders `# gazelle:prefix` from the
same project name as its `go.mod`, so the two always agree. Both were found by
stamping into a real monorepo whose `go.mod` had outlived its scaffold identity
([vitruvian-core#1809](https://github.com/VitruvianSoftware/vitruvian-core/issues/1809)),
and both are now gated in `app-contract` against purpose-built scratch hosts —
including a negative control with neither directive, which is what keeps starter
behaviour byte-identical.

A fourth convention is a property of the host's gazelle **configuration**: the
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

`template/tools/initializer/config.json` declares the languages and their
`template_dir`, the concerns and their `requires` chains, the deploy targets and
their database providers, the HTTP frameworks, the presets, the render rules,
and `template_suffix`. It ships with the engine, so every stamped repo has its
own copy, and every frontend reads the copy belonging to the repo it is stamping
into. (Repo stamping's own config stays where it was, in the repo-root
`template-config.json`; the two are separate contracts because their globs are
relative to different trees.)

Change it and run both checks — from the AWT root while developing, and from a
stamped repo if you are extending that repo's copy:

    aspect check-metadata     # the contract is internally consistent
    aspect check-renders      # sampled selections render cleanly

`check-renders` stamps into a scratch directory with no host monorepo above it,
so it supplies the destination-derived values (`import_path`, `package_path`,
`host_oci`) itself. A template that needs another such value must be given one
there too, or the smoke passes on output that could never build.

It renders every sampled selection **twice**, once per `host_oci` branch, because
the template branches on it and an unrendered branch is an unchecked branch
(44 renders in all). What that proves is the *syntax* of both branches, not the
gate semantics — the `copybara-go` leg of the `app-contract` job proves the gate.

Its BUILD.bazel assertion checks for a target *named* after the project
(`name = "<project>`), not merely for the project name appearing somewhere in
the file. The looser form was not a check at all: `importpath` contains the
project name too, so it passed even with every `{{ project_snake }}` in the
template replaced by a literal.

`_EXPECTED_OUTPUTS` in `tasks.axl` pins the exact set of files each language
renders **to**. It is deliberately not read from the contract — the contract is
the thing under test, and an expectation sourced from it would be disabled by the
very typo the gate exists to catch. It is a flat set, so it must be updated for
any change to the rendered file set, not merely for a new language.

## What CI proves, and on which mount

The `app-contract` job in `.github/workflows/ci.yaml`:

| step | mount | proves |
|---|---|---|
| `check-metadata`, `check-renders` | AWT root | the **source** contract is consistent and every sampled selection renders |
| one `render-app` | AWT root | the development mount still runs in place |
| render + normalize `go` and `copybara-go` | — | two hosts that each carry a freshly delivered engine |
| `check-metadata`, `check-renders` | inside the `go` starter | the delivered engine is self-contained and `_base()` resolves the starter mount |
| module-root refusal, 4 spellings | inside the `go` starter | the destructive path refuses, and the host survives |
| explicit-flags convention | inside the `go` starter, `--out` outside it | the P1 frontend shape: clone the target, run its engine, render elsewhere |
| stamp 3 apps + gazelle + `git diff --cached --exit-code` | inside each starter | the gazelle fixed point, on the mount users have |
| `bazel test //app/... //services/...` | inside each starter | a fixed point that actually builds |

## Adding a language

1. Create `template/tools/initializer/app/<language>/`, with every template file
   carrying the `.tmpl` suffix.
2. Add it to `languages` in `template/tools/initializer/config.json` with
   `template_dir` set to `app/<language>`.
3. Add the language to `appliesTo` on each concern it supports.
4. Add its rendered (unsuffixed) file names to `_EXPECTED_OUTPUTS` in
   `template/tools/initializer/tasks.axl`; a language with no entry fails
   `check-renders` rather than being skipped.
5. Run both checks; add a preset so the language gets a full build in CI.
6. Extend the `app-contract` job to stamp the new language into a monorepo that
   has it, or the gazelle fixed point goes unproven for that language.

The whole engine tree reaches a starter through one `no_render` entry,
`tools/initializer/**`, and no `rules` entry — so it is delivered to every one
of the 28 presets, and there is nothing to add when a language is.
