#!/usr/bin/env bash
# Create a worktree from the selected text (a branch name) in the focused pane.
# Bind this action to a key; the worktree.created event then starts OpenCode.
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
ctx="${HERDR_PLUGIN_CONTEXT_JSON:-}"

mapfile -t f < <(printf '%s' "$ctx" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sel = (d.get("selected_text") or "").strip()
branch = sel.splitlines()[0].strip().replace(" ", "-") if sel else ""
repo = d.get("focused_pane_cwd") or d.get("workspace_cwd") or ""
print(branch)
print(repo)
')
branch="${f[0]:-}"
repo="${f[1]:-}"

if [ -z "$branch" ]; then
    "$herdr" notification show "No branch selected" \
        --body "Select a branch name in a pane, then run this action again." \
        --sound request >/dev/null 2>&1 || true
    exit 0
fi

# Refuse a branch that is already checked out in another worktree.
if [ -n "$repo" ] && git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    where="$(git -C "$repo" worktree list --porcelain | awk -v ref="refs/heads/$branch" '
        /^worktree / { p = substr($0, 10) }
        /^branch /   { if ($2 == ref) print p }')"
    if [ -n "$where" ]; then
        "$herdr" notification show "Branch already checked out" \
            --body "$branch is open in $where" --sound request >/dev/null 2>&1 || true
        exit 0
    fi
fi

"$herdr" worktree create --cwd "$repo" --branch "$branch" --label "${branch##*/}" --focus