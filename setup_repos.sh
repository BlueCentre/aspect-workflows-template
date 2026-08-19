#!/usr/bin/env bash
# Provisions the delivery credentials the "Deliver starters" workflow needs: one
# write-capable deploy key per starter repo, with its private half stored as
# STARTER_DEPLOY_<PRESET> in this repo.
#
# Safe to re-run. By default it only provisions what is missing, so it doubles as
# the repair tool for a starter repo whose key was lost or revoked. Pass --rotate
# to replace existing keys instead.
#
# Usage: ./setup_repos.sh [--rotate]
set -euo pipefail

ORG="VitruvianSoftware"
SECRETS_REPO="$ORG/aspect-workflows-template"
KEY_TITLE="Delivery Pipeline Key"
DELIVER_WORKFLOW="$(cd "$(dirname "$0")" && pwd)/.github/workflows/deliver.yaml"

ROTATE=0
case "${1:-}" in
    --rotate) ROTATE=1 ;;
    "") ;;
    *) echo "usage: $0 [--rotate]" >&2; exit 2 ;;
esac

# The preset list is read from deliver.yaml rather than duplicated here. The
# duplicate is what let the two drift: this script listed 10 presets while
# deliver publishes 26, so a repair run silently skipped 16 starter repos and
# reported success.
PRESETS="$(awk '
    /^ *preset: *$/  { in_list = 1; next }
    in_list && /^ *- / { sub(/^ *- */, ""); print; next }
    in_list          { exit }
' "$DELIVER_WORKFLOW")"

if [ -z "$PRESETS" ]; then
    echo "❌ No presets parsed from $DELIVER_WORKFLOW -- refusing to run." >&2
    echo "   The matrix shape probably changed; fix the parser rather than" >&2
    echo "   re-adding a hardcoded list that can drift again." >&2
    exit 1
fi
echo "Presets from deliver.yaml: $(printf '%s\n' "$PRESETS" | wc -l | tr -d ' ') found"

for preset in $PRESETS; do
    REPO_NAME="$ORG/$preset"
    # tr, not ${var^^}: that expansion is bash 4+, and macOS ships bash 3.2 as
    # /bin/bash, where this script died on "bad substitution" before doing
    # anything at all.
    SECRET_NAME="STARTER_DEPLOY_$(printf '%s' "$preset" | tr 'a-z-' 'A-Z_')"

    echo "----------------------------------------------------------------"
    echo "Processing $preset  (repo: $REPO_NAME, secret: $SECRET_NAME)"

    # 1. Create the repository if it does not exist.
    if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
        echo "✅ Repository exists"
    else
        echo "Creating repository $REPO_NAME..."
        if ! gh repo create "$REPO_NAME" --public --description "Aspect Workflows Template for $preset"; then
            echo "❌ Failed to create $REPO_NAME -- needs permission to create repositories in $ORG." >&2
            exit 1
        fi
        echo "✅ Created"
    fi

    # 2. Decide whether this repo needs a key at all.
    EXISTING_IDS="$(gh repo deploy-key list -R "$REPO_NAME" --json id,title \
        --jq ".[] | select(.title | startswith(\"$KEY_TITLE\")) | .id" 2>/dev/null || true)"

    if [ -n "$EXISTING_IDS" ] && [ "$ROTATE" -eq 0 ]; then
        echo "⏭  Already has a delivery key -- leaving it alone (--rotate to replace)"
        continue
    fi

    # 3. Rotating: drop the old keys FIRST. The previous version of this script
    #    only ever added, so every run left another write-capable key on the repo
    #    -- unused, unrotated, and still valid.
    if [ -n "$EXISTING_IDS" ]; then
        for id in $EXISTING_IDS; do
            echo "🗑  Removing previous delivery key $id"
            gh repo deploy-key delete "$id" -R "$REPO_NAME"
        done
    fi

    # 4. Mint the key, register the public half, store the private half.
    KEY_FILE="$(mktemp -u "${TMPDIR:-/tmp}/id_ed25519_${preset}_XXXXXX")"
    trap 'rm -f "$KEY_FILE" "$KEY_FILE.pub"' EXIT
    ssh-keygen -t ed25519 -C "delivery-bot@aspect-workflows" -f "$KEY_FILE" -N "" -q

    if ! gh repo deploy-key add "$KEY_FILE.pub" -R "$REPO_NAME" --allow-write --title "$KEY_TITLE"; then
        echo "❌ Failed to add deploy key to $REPO_NAME." >&2
        exit 1
    fi
    echo "✅ Deploy key added"

    if ! gh secret set "$SECRET_NAME" < "$KEY_FILE" -R "$SECRETS_REPO"; then
        echo "❌ Failed to set $SECRET_NAME in $SECRETS_REPO." >&2
        exit 1
    fi
    echo "✅ Secret $SECRET_NAME set"

    rm -f "$KEY_FILE" "$KEY_FILE.pub"
    trap - EXIT
done

echo "----------------------------------------------------------------"
echo "🎉 Delivery credentials in place for every preset deliver.yaml publishes."
