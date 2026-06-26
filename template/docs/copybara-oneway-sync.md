# Copybara one-way PR-import (onboarding runbook)

This monorepo was scaffolded with **one-way** Copybara sync: the monorepo is the
single source of truth and each standalone repo is an **export-only mirror**.
External contributions come back as **labelled mirror PRs imported into the
monorepo** for review — there is no push-to-main import (that is the bidirectional
shape, see `copybara-bidi-sync.md`). One-way removes the #1 scaling risk of two
writable-authoritative copies drifting apart.

## How it works

```
monorepo/<comp>/  --export_<comp>-->  <org>/<comp> (mirror, main)   [SSH deploy key]
contributor opens PR on the mirror
maintainer applies the `import-to-monorepo` label
copybara-import-pr.yaml (cron */15)  --import_pr_<comp>-->  monorepo PR under <comp>/   [App token]
maintainer reviews + merges the monorepo PR
copybara-import-pr-close.yaml  comments + closes the mirror PR
next export reflects the merged change back to the mirror
```

Contributor flow on a mirror: **open PR → sign the CLA → a maintainer labels it →
auto-import (~15 min) → review/merge in the monorepo → the mirror PR auto-closes.**

## One-time setup

1. **Edit `tools/copybara/copy.bara.sky`**: set `GITHUB_ORG` to your org.
2. **GitHub App** (the credential for import): the `copybara_pulumi_auth` IaC
   (`infrastructure/pulumi/copybara_sync`) provisions the `SYNC_APP_ID` /
   `SYNC_APP_PRIVATE_KEY` Actions secrets. The App itself must be:
   - granted **Pull requests: write** (plus Contents: write, Metadata: read), and
   - **installed on the monorepo and every one-way mirror repo** (Only-select-repositories).
   Token minting fails closed if a mirror was not added to the installation.
3. **Seed each export baseline** once: run the per-component
   `copybara-export-<comp>.yaml` with `--force --ignore-noop` (see
   `copybara-bidi-sync.md` §export — the export side is identical for both shapes).

## Onboarding a one-way component

For a component `<comp>` whose mirror is `<org>/<comp>`:

1. **`tools/copybara/copy.bara.sky`** — append to `COMPONENTS` with
   `"is_one_way": True` (the scaffold did this for the initial components):
   ```python
   {"name": "<comp>", "standalone_rev_id": "<COMP>_REV_ID",
    "standalone_only": [".github/workflows/sync-to-monorepo.yaml"], "is_one_way": True},
   ```
3. **Export wrapper** — add `.github/workflows/copybara-export-<comp>.yaml`
   (a thin caller of `_copybara-export.yaml`; see `copybara-bidi-sync.md` §8f).
4. **Import matrix** — add `<comp>` to the `matrix.component` list in
   `.github/workflows/copybara-import-pr.yaml` **and** to the allowlist `case` in
   `.github/workflows/copybara-import-pr-close.yaml`.
5. **CLA** (gates external contributions) — copy `tools/copybara/cla/cla.yml` to
   `<comp>/.github/workflows/cla.yml` and `tools/copybara/cla/CLA.md` to
   `<comp>/CLA.md`, replacing `<org>/<component>`. The export carries both to the
   mirror; CLA Assistant Lite then runs in the mirror.
6. **Gate label** — create the `import-to-monorepo` label on the mirror:
   `gh label create import-to-monorepo --repo <org>/<comp> --color 1D76DB \
     --description "Maintainer gate: import this PR into the monorepo"`.
7. **Mention the flow** in the mirror's `CONTRIBUTING.md` (the export carries it
   down): open PR → sign CLA → maintainer labels → auto-import → review/merge →
   mirror PR auto-closes.

## How the import is invoked (pinned-image notes)

The import runs through the tested Go wrapper
`//tools/copybara/sync import_pr <comp> <pr>`, which works around three quirks of
the pinned 2023-01 `olivr/copybara` image (the export/bidi paths are unaffected):

- the image entrypoint is **env-driven and ignores CLI args**, so the PR number is
  passed via `COPYBARA_SOURCEREF`;
- the image does **not resolve `${GITHUB_PR_NUMBER}`** in `pr_branch`/`body`, so
  `copy.bara.sky` uses an `@@PR_NUMBER@@` placeholder that the wrapper substitutes
  per run;
- `actions/checkout` shadows the App-token credential store, so
  `copybara-import-pr.yaml` sets `persist-credentials: false` for the tidy push.

## Switching a component between shapes

Flip `is_one_way` in `copy.bara.sky` and move its workflow wiring: one-way uses
`copybara-import-pr.yaml` (+ `-close.yaml`); bidirectional uses a per-component
`copybara-import-<comp>.yaml` caller of `_copybara-import.yaml` plus
`copybara-drift-check.yaml`. The `export_<comp>` workflow is identical for both.
