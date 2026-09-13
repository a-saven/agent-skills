#!/usr/bin/env bash
# Symlink every skill, agent, bin script and hook in this repo into ~/.claude so
# Claude Code picks them up globally. Idempotent — re-run after `git pull`
# (symlinks mean updates land automatically anyway). `--uninstall` removes
# exactly what this script added and nothing else; the settings backup it made stays.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
BIN_DIR="$HOME/.claude/bin"
LOCAL_BIN="$HOME/.local/bin"
HOOKS_DIR="$HOME/.claude/hooks/agent-skills"
SETTINGS="$HOME/.claude/settings.json"

# Entries are matched in settings.json by their exact command string, so changing
# one here orphans the copy earlier installs wrote.
hook_entries() {
cat <<'JSON'
{
  "SessionStart": [
    {"hooks": [{"type": "command", "command": "d=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; g=\"$HOME/.claude/bin/graphs\"; [ -x \"$g\" ] && (cd \"$d\" && nohup \"$g\" ensure >/dev/null 2>&1 &); true"}]},
    {"matcher": "startup|clear|compact", "hooks": [{"type": "command", "command": "\"$HOME/.claude/hooks/agent-skills/handoff-load.sh\"", "timeout": 5}]}
  ],
  "UserPromptSubmit": [
    {"hooks": [{"type": "command", "command": "\"$HOME/.claude/hooks/agent-skills/context-nudge.sh\"", "timeout": 5}]}
  ],
  "PostToolUse": [
    {"matcher": "Bash|Edit|Write|Agent", "hooks": [{"type": "command", "command": "\"$HOME/.claude/hooks/agent-skills/context-nudge.sh\"", "timeout": 5}]}
  ],
  "SubagentStop": [
    {"matcher": "^(agent-skills:)?(architect|manual-qa)$", "hooks": [{"type": "command", "command": "\"$HOME/.claude/hooks/agent-skills/memory-guard.sh\"", "timeout": 5}]}
  ]
}
JSON
}

edit_settings() {  # add | remove
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  python3 not found — could not edit $SETTINGS."
    [ "$1" = add ] && echo "  Merge these into its \"hooks\" object by hand:" \
                   || echo "  Remove these from its \"hooks\" object by hand:"
    hook_entries | sed 's/^/    /'
    return 0
  fi
  python3 - "$SETTINGS" "$1" "$(hook_entries)" <<'PY'
import json, os, shutil, sys
path, mode, want = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
try:
    settings = json.load(open(path)) if os.path.exists(path) else {}
except ValueError:
    sys.exit(f"  {path} is not valid JSON — fix it, then re-run")
hooks = settings.setdefault("hooks", {})
changed = False

def commands(entry):
    return [h.get("command", "") for h in entry.get("hooks", [])]

def label(cmd):
    return "graphs ensure" if "graphs" in cmd else os.path.basename(cmd.strip('"'))

if mode == "add":
    for event, entries in want.items():
        have = hooks.setdefault(event, [])
        present = {c for e in have for c in commands(e)}
        for entry in entries:
            names = ", ".join(label(c) for c in commands(entry))
            if all(c in present for c in commands(entry)):
                print(f"  hook already present: {event} ({names})")
            else:
                have.append(entry)
                changed = True
                print(f"  ✓ added {event} hook ({names})")
else:
    own = {c for entries in want.values() for e in entries for c in commands(e)}
    for event in list(hooks):
        kept, touched = [], False
        for entry in hooks[event]:
            mine = [h for h in entry.get("hooks", []) if h.get("command") in own]
            if not mine:
                kept.append(entry)
                continue
            touched = changed = True
            for h in mine:
                print(f"  ✓ removed {event} hook ({label(h['command'])})")
            entry["hooks"] = [h for h in entry["hooks"] if h.get("command") not in own]
            if entry["hooks"]:
                kept.append(entry)
        if touched:
            if kept:
                hooks[event] = kept
            else:
                del hooks[event]
    if changed and not hooks:
        del settings["hooks"]
    if not changed:
        print("  no agent-skills hooks found in settings.json")

if changed:
    bak = path + ".bak-agent-skills"
    if os.path.exists(path) and not os.path.exists(bak):
        shutil.copy2(path, bak)
        print(f"  backed up settings.json → {bak}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
PY
}

plugin_enabled() {
  command -v claude >/dev/null 2>&1 || return 1
  claude plugin list 2>/dev/null | awk '
    /agent-skills@/ { hit = 1; next }
    hit && /Status:/ { if ($0 ~ / enabled/) found = 1; hit = 0 }
    END { exit !found }'
}

link_into() {  # <dir> <file>...
  dir=$1; shift
  mkdir -p "$dir"
  for src in "$@"; do
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    target="$dir/$name"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "  ! $name exists and is not a symlink — skipping (remove it to adopt this repo's copy)"
      continue
    fi
    ln -sfn "${src%/}" "$target"
    echo "  ✓ $name"
  done
}

uninstall() {
  echo "Removing symlinks that point into $REPO_DIR"
  for dir in "$SKILLS_DIR" "$AGENTS_DIR" "$BIN_DIR" "$LOCAL_BIN" "$HOOKS_DIR"; do
    for f in "$dir"/*; do
      [ -L "$f" ] || continue
      case "$(readlink "$f")" in "$REPO_DIR"/*) rm -f "$f"; echo "  ✓ removed $f";; esac
    done
  done
  rmdir "$HOOKS_DIR" 2>/dev/null || true
  echo "Removing hooks from $SETTINGS"
  edit_settings remove
  echo
  echo "Done. Restart Claude Code once so the skills and agents unload."
}

case "${1:-}" in
  "") ;;
  --uninstall) uninstall; exit 0;;
  *) echo "usage: install.sh [--uninstall]"; exit 2;;
esac

if plugin_enabled; then
  echo "agent-skills is already installed and enabled as a Claude Code plugin (claude plugin list)."
  echo "Use one install path at a time: run 'claude plugin uninstall agent-skills' first, or skip install.sh."
  exit 1
fi

echo "Installing skills → $SKILLS_DIR"
link_into "$SKILLS_DIR" "$REPO_DIR"/skills/*/

echo "Installing agents → $AGENTS_DIR"
link_into "$AGENTS_DIR" "$REPO_DIR"/agents/*.md

echo "Installing bin/ (graphs, memory-lint) → $BIN_DIR and $LOCAL_BIN"
link_into "$BIN_DIR" "$REPO_DIR"/bin/graphs "$REPO_DIR"/bin/memory-lint
link_into "$LOCAL_BIN" "$REPO_DIR"/bin/graphs "$REPO_DIR"/bin/memory-lint | { grep -v '✓' || true; }
echo "  (ensure $LOCAL_BIN is on your PATH)"

echo "Installing hooks → $HOOKS_DIR"
link_into "$HOOKS_DIR" "$REPO_DIR"/hooks/*.sh

echo "Registering hooks in $SETTINGS (graphs ensure, handoff loader, context nudge, memory guard)"
edit_settings add
command -v codegraph >/dev/null 2>&1 || \
  echo "  NOTE: codegraph not found — npm i -g @colbymchenry/codegraph, then 'codegraph init' per repo"

echo
echo "Done. Restart Claude Code once so the skills and agents load."
echo "Note: the qa-run/manual-qa pair uses the Playwright MCP; register it with:"
echo "  claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless"
