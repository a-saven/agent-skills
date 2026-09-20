#!/bin/sh
# Runs install.sh against a throwaway HOME: install twice, uninstall, and refuse
# when the plugin is enabled. No network, no API.
set -u

REPO=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
H="$TMP/home"
S="$H/.claude/settings.json"
SEED="$TMP/seed.json"
fail=0

ok() { name=$1; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=1; fi; }
count() { grep -c -- "$1" "$S" 2>/dev/null || true; }
contains() { printf '%s' "$2" | grep -E -q -- "$1"; }
links_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }

all_linked() {
  for s in "$REPO"/skills/*/; do links_to "$H/.claude/skills/$(basename "$s")" "${s%/}" || return 1; done
  for a in "$REPO"/agents/*.md; do links_to "$H/.claude/agents/$(basename "$a")" "$a" || return 1; done
  for b in "$REPO"/bin/graphs "$REPO"/bin/memory-lint; do
    links_to "$H/.claude/bin/$(basename "$b")" "$b" || return 1
    links_to "$H/.local/bin/$(basename "$b")" "$b" || return 1
  done
  for h in "$REPO"/hooks/*.sh; do
    [ -e "$h" ] || continue
    links_to "$H/.claude/hooks/agent-skills/$(basename "$h")" "$h" || return 1
  done
}

none_linked() {
  for d in "$H/.claude/skills" "$H/.claude/agents" "$H/.claude/bin" "$H/.claude/hooks/agent-skills" "$H/.local/bin"; do
    for f in "$d"/*; do
      [ -L "$f" ] || continue
      case "$(readlink "$f")" in "$REPO"/*) return 1;; esac
    done
  done
}

mkdir -p "$H/.claude"
printf '{\n  "model": "sonnet",\n  "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo keep-me"}]}]}\n}\n' > "$SEED"
cp "$SEED" "$S"

out=$(HOME="$H" sh "$REPO/install.sh" 2>&1); rc=$?
ok "install exits 0" test "$rc" -eq 0
ok "every skill, agent, bin script and hook is symlinked into the repo" all_linked
for f in bin/memory-lint hooks/context-nudge.sh hooks/handoff-load.sh hooks/memory-guard.sh; do
  if [ -e "$REPO/$f" ]; then
    case $f in bin/*) t="$H/.claude/bin/$(basename "$f")";; *) t="$H/.claude/hooks/agent-skills/$(basename "$f")";; esac
    ok "$f symlinked" links_to "$t" "$REPO/$f"
  else
    echo "SKIP  $f symlinked (not in repo)"
  fi
done
ok "graphs ensure hook written once" test "$(count 'ensure >/dev/null')" -eq 1
ok "handoff loader on SessionStart startup|clear|compact" test "$(count 'agent-skills/handoff-load.sh')" -eq 1 -a "$(count '"startup|clear|compact"')" -eq 1
ok "context nudge on UserPromptSubmit and PostToolUse" test "$(count 'agent-skills/context-nudge.sh')" -eq 2 -a "$(count '"Bash|Edit|Write|Agent"')" -eq 1
ok "memory guard on SubagentStop for architect and manual-qa" test "$(count 'agent-skills/memory-guard.sh')" -eq 1 -a "$(count '(architect|manual-qa)')" -eq 1 -a "$(count '"SubagentStop"')" -eq 1
ok "foreign hook and settings survive install" test "$(count 'echo keep-me')" -eq 1 -a "$(count '"model": "sonnet"')" -eq 1
ok "settings.json backed up before the first write" cmp -s "$S.bak-agent-skills" "$SEED"
if command -v python3 >/dev/null 2>&1; then
  ok "settings.json still parses" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$S"
fi

cp "$S" "$TMP/after-first.json"
out=$(HOME="$H" sh "$REPO/install.sh" 2>&1); rc=$?
ok "second install exits 0" test "$rc" -eq 0
ok "second install reports all five hooks already present" test "$(printf '%s\n' "$out" | grep -c 'already present')" -eq 5
ok "second install leaves settings.json unchanged" cmp -s "$S" "$TMP/after-first.json"
ok "backup is not overwritten" cmp -s "$S.bak-agent-skills" "$SEED"

out=$(HOME="$H" sh "$REPO/install.sh" --uninstall 2>&1); rc=$?
ok "uninstall exits 0" test "$rc" -eq 0
ok "uninstall prints what it removed" contains 'removed .*(hooks/agent-skills|skills/orchestrate)' "$out"
ok "uninstall prints the memory guard hook and symlink" test "$(printf '%s\n' "$out" | grep -c 'removed .*memory-guard.sh')" -eq 2
ok "uninstall removes every symlink into the repo" none_linked
ok "uninstall removes the agent-skills hooks" test "$(count 'agent-skills/')" -eq 0 -a "$(count 'ensure >/dev/null')" -eq 0
ok "uninstall removes the SubagentStop event it added" test "$(count '"SubagentStop"')" -eq 0
ok "uninstall keeps the foreign hook and settings" test "$(count 'echo keep-me')" -eq 1 -a "$(count '"model": "sonnet"')" -eq 1

SHIM="$TMP/shim"; mkdir -p "$SHIM"
printf '#!/bin/sh\nprintf "Installed plugins:\\n\\n  > agent-skills@a-saven\\n    Version: 0.2.0\\n    Scope: user\\n    Status: v enabled\\n"\n' > "$SHIM/claude"
chmod +x "$SHIM/claude"
H2="$TMP/home-plugin"; mkdir -p "$H2"
out=$(HOME="$H2" PATH="$SHIM:$PATH" sh "$REPO/install.sh" 2>&1); rc=$?
ok "install refuses while the plugin is enabled" test "$rc" -eq 1
ok "refusal says one install path at a time" contains 'one install path at a time' "$out"
ok "refusal installs nothing" test ! -e "$H2/.claude/skills"

printf '#!/bin/sh\nprintf "Installed plugins:\\n\\n  > agent-skills@a-saven\\n    Version: 0.2.0\\n    Scope: user\\n    Status: x disabled\\n"\n' > "$SHIM/claude"
out=$(HOME="$H2" PATH="$SHIM:$PATH" sh "$REPO/install.sh" 2>&1); rc=$?
ok "install proceeds while the plugin is disabled" test "$rc" -eq 0 -a -L "$H2/.claude/skills/orchestrate"

exit $fail
