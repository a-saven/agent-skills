#!/bin/sh
# SubagentStop for architect and manual-qa: lint the agent's MEMORY.md and hand the messages back once as its next instruction.
# A one-shot repair prompt, not enforcement: stop_hook_active, a missing lint, or any error exits 0 silently.
set -u

input=$(cat 2>/dev/null) || exit 0
if command -v python3 >/dev/null 2>&1; then
  parsed=$(printf '%s' "$input" | python3 -c 'import json,sys
d=json.load(sys.stdin)
if not isinstance(d,dict): raise SystemExit(1)
for v in ("stop" if d.get("stop_hook_active") is True else "go", d.get("agent_type") or "", d.get("cwd") or ""): print(str(v).replace("\n"," "))' 2>/dev/null) || exit 0
  stop=$(printf '%s\n' "$parsed" | sed -n 1p); agent=$(printf '%s\n' "$parsed" | sed -n 2p); cwd=$(printf '%s\n' "$parsed" | sed -n 3p)
else
  field() { printf '%s' "$input" | grep -o "\"$1\" *: *\"[^\"]*\"" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/; s|\\/|/|g'; }
  printf '%s' "$input" | grep -q '"stop_hook_active" *: *true' 2>/dev/null && stop=stop || stop=go
  agent=$(field agent_type); cwd=$(field cwd)
fi
[ "$stop" = stop ] && exit 0
agent=${agent#agent-skills:}
case $agent in architect|manual-qa) ;; *) exit 0 ;; esac
[ -n "$cwd" ] || cwd=${CLAUDE_PROJECT_DIR:-$PWD}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=$cwd
rel=".claude/agent-memory-local/$agent/MEMORY.md"
[ -f "$root/$rel" ] || exit 0

lint=""
for candidate in "$(dirname "$0")/../bin/memory-lint" "${HOME:-}/.claude/bin/memory-lint" "$(command -v memory-lint 2>/dev/null)"; do
  [ -n "$candidate" ] && [ -x "$candidate" ] && { lint=$candidate; break; }
done
[ -n "$lint" ] || exit 0

out=$("$lint" "$root/$rel" 2>/dev/null); rc=$?
[ "$rc" -eq 1 ] && [ -n "$out" ] || exit 0
msgs=$(printf '%s\n' "$out" | head -n 8 | tr '\t' ' ' | tr -d '\000-\011\013-\037' | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{ s = s (NR > 1 ? "\\n" : "") $0 } END { printf "%s", s }')
printf '{"decision":"block","reason":"memory-lint failed for %s — fix these lines, then finish:\\n%s"}\n' "$rel" "$msgs"
exit 0
