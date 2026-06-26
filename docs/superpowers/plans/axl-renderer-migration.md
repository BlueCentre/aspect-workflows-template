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
  - [ ] C: license-check (LICENSE 4-way, addlicense tool, workflow, tools.lock entry, header block macro — must render identically to stay tidy-clean).
  - F: RBE/remote-build + build-cache menu + key-rotation SOP.
  - K: devcontainer (kitchen-sink Dockerfile, kind, arch-aware).
  - O: format/prettier wrapper, `.gitattributes` lint-ignores, misc tool tweaks.
- [ ] **Phase 3 — Swift (H).** flag+preset+rules+`template/swift/`+MODULE block+swiftformat+`git_override`+user story+dep-versioning page.
- [ ] **Phase 4 — Big subsystems:**
  - D: Copybara bidi + one-way (engine Go, workflows, CLA, `go_or_copybara` flag, auth IaC, docs).
  - E1/E2: Pulumi `repo_config` + Bazel-wrapped pulumi tooling + create-app.
- [ ] **Phase 5 — Backstage (I).** template.yaml + skeleton + dual catalog-info + the post-render skeleton-copy mechanism.
- [ ] **Phase 6 — Template-tooling:** release-please (M), template Pulumi infra E3, `deliver.yaml`/CI rewired to `aspect render-preset` (N), docs site + dependency-versioning generated guide (J), `setup_repos.sh`/`test.sh` equivalents.
- [ ] **Phase 7 — Full matrix verification + delivery.** All presets (incl. backstage-* and swift) render→build→test→story green in CI; deliver to starters; spot-check.

## Notes / landmines
- Every generated file with a license header must render byte-identical so `//:tidy` stays a fixed point (our hard CI rule). Re-express the 4-way header as one jinja macro/partial, applied everywhere.
- `go_or_copybara`: our computed flag shipping Go tooling for the copybara engine in non-Go repos — must be reproduced (a derived flag in `render.axl`/`template-config.json` or precomputed per preset).
- The three-way copybara gating (shared / bidi-only / one-way-only / pulumi-auth) is the densest conditional set.
- `.aspect/config.axl` is where lint-aspect lists and delivery query/flags are wired (per-language `{% if %}`).
