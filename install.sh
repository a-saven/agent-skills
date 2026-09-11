#!/usr/bin/env bash
# Symlink every skill and agent in this repo into ~/.claude so Claude Code
# picks them up globally. Idempotent — re-run after `git pull` (symlinks mean
# updates land automatically anyway).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"

mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"

echo "Installing skills → $SKILLS_DIR"
for skill in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill")"
  target="$SKILLS_DIR/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "  ! $name exists and is not a symlink — skipping (remove it to adopt this repo's copy)"
    continue
  fi
  ln -sfn "${skill%/}" "$target"
  echo "  ✓ $name"
done

echo "Installing agents → $AGENTS_DIR"
for agent in "$REPO_DIR"/agents/*.md; do
  name="$(basename "$agent")"
  target="$AGENTS_DIR/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "  ! $name exists and is not a symlink — skipping (remove it to adopt this repo's copy)"
    continue
  fi
  ln -sfn "$agent" "$target"
  echo "  ✓ $name"
done

echo "Installing the graphs CLI (worktree-graphs)"
mkdir -p "$HOME/.claude/bin"
ln -sfn "$REPO_DIR/bin/graphs" "$HOME/.claude/bin/graphs"
BINDIR="$HOME/.local/bin"; mkdir -p "$BINDIR"
ln -sfn "$REPO_DIR/bin/graphs" "$BINDIR/graphs"
echo "  ✓ graphs → $BINDIR/graphs (ensure $BINDIR is on your PATH)"

# SessionStart hook: seed/sync code graphs when a session opens in a worktree.
SETTINGS="$HOME/.claude/settings.json"
HOOK='d="${CLAUDE_PROJECT_DIR:-$PWD}"; g="$HOME/.claude/bin/graphs"; [ -x "$g" ] && (cd "$d" && nohup "$g" ensure >/dev/null 2>&1 &); true'
python3 - "$SETTINGS" "$HOOK" <<'PY'
import json, os, sys
path, hook = sys.argv[1], sys.argv[2]
d = json.load(open(path)) if os.path.exists(path) else {}
hooks = d.setdefault("hooks", {}).setdefault("SessionStart", [])
flat = [h for e in hooks for h in e.get("hooks", [])]
if any("graphs" in h.get("command", "") and "ensure" in h.get("command", "") for h in flat):
    print("  hook already present — skipping")
else:
    hooks.append({"hooks": [{"type": "command", "command": hook}]})
    json.dump(d, open(path, "w"), indent=2); open(path, "a").write("\n")
    print("  ✓ added SessionStart hook (graphs ensure)")
PY
command -v codegraph >/dev/null 2>&1 || \
  echo "  NOTE: codegraph not found — npm i -g @colbymchenry/codegraph, then 'codegraph init' per repo"

echo
echo "Done. Restart Claude Code once so the skills and agents load."
echo "Note: the qa-run/manual-qa pair uses the Playwright MCP; register it with:"
echo "  claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless"
