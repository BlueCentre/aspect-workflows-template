# AGENTS.md

Guidance for AI coding agents working in this repo (useful for humans too). This is a
hermetic, multi-language Bazel monorepo generated from the Aspect Workflows starter template.

## Build, test, run
- Dev environment: `bazel run //tools:bazel_env` (with [direnv](https://direnv.net); `direnv allow`).
- Build / test: `bazel build //...` and `bazel test //...`.
{{- if .Scaffold.lint }}
- Lint / format: `aspect lint //...` and `format`.
{{- end }}
- Regenerate `BUILD` files after adding/moving code: `bazel run //:gazelle`.

## Conventions & landmines
- **Gazelle owns most `BUILD` files** — don't hand-edit generated targets; change the source
  and re-run gazelle.
- **One Version Rule** — one resolved version per dependency per ecosystem. To deliberately
  diverge, add a *separate* hub/module, don't add a second version to the shared hub. See
  `docs/dependency-versioning/`.
- **Dependency changes** = edit the manifest, then re-lock, then gazelle (e.g. Python
  `./tools/repin`; Go `go mod tidy` + `bazel mod tidy`; JS `pnpm add`; JVM `bazel run @maven//:pin`).
{{- if .Scaffold.license }}
- **License headers are enforced** — run the license add helper before committing.
{{- end }}
- **Build cache:** both a local `--disk_cache` (opt-in; see `user.bazelrc.example`) and remote
  RBE via `--config=remote` are available — no vendor is forced. See `tools/remote` and `user.bazelrc`.
{{- if .Scaffold.copybara }}

## Copybara (component sync)
Synced components also live as standalone repos. Never delete standalone-only files or import
monorepo-only ones — respect `standalone_only` (e.g. `package-lock.json`,
`.github/workflows/sync-to-monorepo.yaml`) and the gazelle-generated `BUILD` files
(monorepo-only). See `docs/copybara-bidi-sync.md`.
{{- end }}

## Conventions
- **Conventional commits** (`feat:`, `fix:`, `chore:`, `docs:` …).
- Planning/design docs under `docs/` marked `status: completed` are done — don't treat them as
  open TODOs.
