# Migration plan: Scaffold engine → upstream native AXL renderer

**Branch:** `feat/axl-renderer-migration` (off `platform-v2.0`)
**Goal:** Adopt upstream's new AXL renderer (replaces the fragile `hay-kot/scaffold` engine) as our base, and re-port all of our fork's features on top of it, so we are mergeable with upstream again and off the deprecated engine.

## Target engine (what we are adopting)

Upstream commit `dee74d3` (2026-06-16) replaced `scaffold.yaml` + `{{ .ProjectSnake }}/` Go-template tree with:
- `template-config.json` — `flags` (language/feature vocab), `presets` (name→flag dict), `rules` (glob→predicate file inclusion), `no_render` (byte-copy list), `executable` (+x list).
- `template/` — jinja2 (minijinja) source tree. In-file conditionals are `{% if flag %}…{% endif %}`. Name var is `{{ project_snake }}` (+ `project_kebab`, `project_pascal`, `project_name`).
- `render.axl` (generic renderer) + `dev.axl` (`render_preset` task) + `MODULE.aspect` (`use_task`).
- Rendered via the **Aspect CLI**: `aspect render-preset --preset <p> --out <dir> --name <name> [--license=Apache-2.0]`. No `scaffold` binary, no `hooks/post_scaffold`.
- File **existence** = JSON `rules`; in-file **content** = jinja `{% if %}`. Literal `${{ }}` in rendered workflows is escaped `${{ '{{' }} … {{ '}}' }}`, or the file is placed on `no_render`.

Local tooling: Aspect CLI installed at `~/.local/bin/aspect` (v2026.26.25, matches `template/.aspect/version.axl`).

## Verification loop (every phase)

```
~/.local/bin/aspect render-preset --preset <p> --out /tmp/axl-<p> --name my_project
cd /tmp/axl-<p> && ./tools/repin (if present); git init && git add -A && git commit -m x
bazel run //:tidy            # must be a no-op (fixed point) — our hard rule
bazel test //...             # or per-user-story
sh $REPO/user_stories/<p>.md # executable-markdown story
```
A preset is "done" when render → tidy(no-op) → build/test/story all pass.

## Strategic decisions (defaults chosen; revisit if wrong)

1. **Adopt upstream's 9.1.1 + `aspect_rules_lint` 2.7.1 base and DROP our rubocop SARIF patch.** Our feature G (9.1.1, rules_go/rules_nodejs floors, rubocop patch) is largely redundant on the new base — upstream is already on 9.1.1, and 2.7.1 fixes the rubocop SARIF bug our patch worked around. Keep only deltas upstream lacks (verify: macOS arm64 LLVM 17.0.6 darwin fix).
2. **Keep OUR delivery/release infra, adapted to the new engine.** We keep `deliver.yaml` → `VitruvianSoftware/<preset>` starters, release-please, and Pulumi-managed deploy keys — but rewire them to call `aspect render-preset` instead of `scaffold new`. We do NOT adopt upstream's `publish-starters.yaml`/`tag.yaml` wholesale (they target `aspect-starters/*` and a different release model).
3. **Swift stays ours** — add a `swift` flag + preset + `template/` files + `git_override` for the hermetic toolchain.
4. **Backstage** needs a render-time post-step (upstream deleted `hooks/post_scaffold`). Design in its phase: either a small extra `dev.axl` task or a CI/deliver shell step that builds `skeleton/`.

## Phases

- [x] **Phase 0 — Foundation.** DONE (commit 4c84a97). Engine vendored, old engine removed; minimal/py/go/kitchen-sink render, minimal+py build & test green.
- [x] **Phase 1 — Build-config parity (G).** DONE — **no-op**. Upstream's base already subsumes ALL of our Bazel-upgrade work, and improves on it: Bazel 9.1.1 ✓; `aspect_rules_lint` 2.7.x with rubocop SARIF fixed → **our rubocop patch + single_version_override are obsolete, dropped with the old tree** ✓; rules_go/rules_nodejs CcInfo floors handled by the modern base ✓; **LLVM 19.1.7 across all platforms** (toolchains_llvm 1.8.0, rules_cc 0.2.18) — strictly better than our darwin-arm64→17.0.6 fix, and **cpp builds on Apple Silicon locally (157 actions, exit 0)** ✓; Rust via rules_rs + aspect_rules_lint_rust (the published clippy module we wanted) ✓. Nothing to port.
- **Phase 2 — Independent generated-tree features (low-risk, parallelizable):**
  - [x] L: AGENTS.md (gen-tree) + copilot/gemini wrappers. DONE (commit bcf8aec). Root AGENTS.md/copilot-instructions deferred to Phase 6 (template-tooling).
  - [x] B: `//:tidy` — **DROPPED as subsumed.** The new engine ships unified `aspect gazelle` / `aspect format` / `aspect buildifier` tasks, and its CI enforces the fixed-point via those. A `bazel run //:tidy` multirun over the raw `//tools/gazelle:gazelle` target *diverges* from the canonical `aspect gazelle` (verified: it rewrote BUILD files on a fresh py render), so re-adding it would break the tidy-clean invariant, not help it. Same call as feature G in Phase 1.
  - [x] C: license-check. DONE. Ported `tools/license/{BUILD.bazel,defs.bzl}` (gated on `license` rule), `addlicense` in `tools.lock.json` (made the lock a rendered file, addlicense block gated `{% if license %}` — multitool registers a toolchain per tool and `bazel build //...` fetches eagerly, so it must be conditional), and a static `license-check.yml` (no_render, license-gated rule). **Simplified to Apache-2.0** (the new engine's `license` flag is Apache-or-none; dropped our 4-way SPDX + copyright-holder params); copyright defaults to `{{ project_pascal }}`. **Headers are applied by `bazel run //tools/license:add` at delivery** (not templated per-file — the new engine renders each file in isolation, no shared macro). Verified: license render ships tooling + `:add`→`:check` loop exits 0; no-license render omits it and builds clean. Delivery `:add` step wired in Phase 6.
  - [x] F: RBE/build-cache. DONE. `template/tools/remote/setup.sh` shipped as a **direct executable** (run `./tools/remote/setup.sh`) instead of an sh_binary — avoids forcing `rules_shell` unconditional. Companion `user.bazelrc.example` + `docs/{build-cache,remote-build}.md`, all `no_render` (they print literal `${{ secrets… }}` CI snippets; Go-template escaping converted to literal). `.bazelrc` gains `try-import %workspace%/tools/remote.bazelrc`. Verified render + executable + minimal builds. `key-rotation.md` deferred to Phase 4 (its copybara-secret sections need the copybara flag).
  - [x] K: devcontainer. DONE. Kept upstream's base `.devcontainer/{devcontainer.json,Dockerfile}`; added `Dockerfile.kitchen-sink` (docker + kind + arch-aware bazelisk), `kind-config.yaml`, devcontainer `README.md`, and `tools/scripts/kind-cluster.sh` (header stripped, +x). All `no_render`, shipped unconditionally.
  - [x] O: `.gitattributes` lint-ignores. DONE. Marked `*.axl`, `.vscode/*.json`, `.devcontainer/*.json`, `tools/scripts/*`, `tools/remote/setup.sh` `linguist-generated` so the rules_lint formatter skips them (keeps the format fixed-point). prettier_wrapper deferred — the new engine's `format_multirun` already wires prettier; revisit only if JS presets show format drift in CI. **Format fixed-point is enforced by the new engine's CI format job (Phase 7); the no_render + linguist-generated marks are the defensive measures.**
- [x] **Phase 3 — Swift (H).** DONE (build verification CI-side). Added `swift` flag + `swift` preset + swift→kitchen-sink; inclusion rule for `swift/**` + `hello/swift/**`; `template/swift/{BUILD.bazel,defs.bzl}` (runtime-staging `swift_binary` wrapper + linux config_settings); `hello/swift/` sample (library+binary+XCTest); MODULE.bazel swift block (rules_swift `git_override` for the hermetic toolchain extension + toolchain registration) — added `platforms` dep gated `{% if not oci %}` so the config_settings resolve without duplicating the oci-preset's platforms. **swiftformat deferred** (depends on rules_lint 2.7.1's format extension API — unconfirmed; format just skips .swift meanwhile). Verified: swift renders (46 files); kitchen-sink has exactly one `platforms` dep; py unaffected (builds clean, 0 rules_swift refs). **Local Swift compile blocked by host (CommandLineTools, no Xcode.app — documented limitation); the error is rules_swift's xcode-locator, not the port. CI macos-latest + Linux hermetic legs verify the real build (Phase 7).** `user_stories/swift.md` + dep-versioning page deferred to Phase 6/7.
- [ ] **Phase 4 — Big subsystems:**
  - [x] D: Copybara bidi + one-way. DONE. 24 files ported (Go sync/drift/conflict tools, copy.bara.sky, CLA, workflows, docs, pulumi auth module). Flags `copybara`/`copybara_one_way`/`copybara_pulumi_auth` + a precomputed `copybara_bidi` (engine has no NOT predicate, so `copybara AND NOT one_way` is computed per-preset). `copybara_components` carried as a **list value in the preset dict** (the renderer passes non-boolean preset values to jinja, so `{% for c in copybara_components %}` + `upper`/`replace`/`join` filters work). Avoided `go_or_copybara` by making copybara presets `go=true`. New presets `copybara-go` (bidi) + `copybara-oneway`. Verified: both shapes render with correct file gating (bidi import/drift vs one-way PR-import), no leftover Go-template; **Go tools build + all 3 tests pass**.
  - E1/E2: Pulumi `repo_config` + Bazel-wrapped pulumi tooling + create-app.
- [ ] **Phase 5 — Backstage (I).** template.yaml + skeleton + dual catalog-info + the post-render skeleton-copy mechanism.
- [ ] **Phase 6 — Template-tooling:** release-please (M), template Pulumi infra E3, `deliver.yaml`/CI rewired to `aspect render-preset` (N), docs site + dependency-versioning generated guide (J), `setup_repos.sh`/`test.sh` equivalents.
- [ ] **Phase 7 — Full matrix verification + delivery.** All presets (incl. backstage-* and swift) render→build→test→story green in CI; deliver to starters; spot-check.

## Notes / landmines
- Every generated file with a license header must render byte-identical so `//:tidy` stays a fixed point (our hard CI rule). Re-express the 4-way header as one jinja macro/partial, applied everywhere.
- `go_or_copybara`: our computed flag shipping Go tooling for the copybara engine in non-Go repos — must be reproduced (a derived flag in `render.axl`/`template-config.json` or precomputed per preset).
- The three-way copybara gating (shared / bidi-only / one-way-only / pulumi-auth) is the densest conditional set.
- `.aspect/config.axl` is where lint-aspect lists and delivery query/flags are wired (per-language `{% if %}`).
