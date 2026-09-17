#!/usr/bin/env bash
# Start OpenCode in a freshly created worktree pane.
# Opt out: create the worktree with a label containing "no-agent".
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
event="${HERDR_PLUGIN_EVENT_JSON:-}"
[ -n "$event" ] || exit 0

read_event() {
    printf '%s' "$event" | python3 -c '
import json, sys
d = json.load(sys.stdin)
data = d.get("data", {})
wt = data.get("worktree") or {}
print(data.get("workspace", {}).get("workspace_id", ""))
print(wt.get("branch") or "")
print(wt.get("label") or "")
'
}

mapfile -t fields < <(read_event)
ws="${fields[0]:-}"
branch="${fields[1]:-}"
label="${fields[2]:-}"

[ -n "$ws" ] || exit 0

# Explicit opt-out for bare worktrees.
case "${label,,}" in *no-agent*) exit 0 ;; esac

# Agent names must match [a-z][a-z0-9_-]{0,31}.
src="${branch:-$label}"
name="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-')"
name="${name#-}"
case "$name" in [a-z]*) ;; *) name="w-$name" ;; esac
name="${name:0:32}"

# The fresh pane needs a moment to appear and reach its shell prompt.
for _ in $(seq 1 20); do
    pane="$("$herdr" pane list --workspace "$ws" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
panes = d.get("result", {}).get("panes", [])
print(panes[0]["pane_id"] if panes else "")
')"
    if [ -n "$pane" ] && "$herdr" agent start "$name" --kind opencode --pane "$pane"; then
        exit 0
    fi
    sleep 0.5
done
exit 0
