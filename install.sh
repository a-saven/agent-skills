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

echo
echo "Done. Restart Claude Code once so the skills and agents load."
echo "Note: the qa-run/manual-qa pair uses the Playwright MCP; register it with:"
echo "  claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless"
