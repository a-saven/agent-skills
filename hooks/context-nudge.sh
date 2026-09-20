#!/bin/sh
# Advisory context-usage nudge for UserPromptSubmit and PostToolUse.
# The cheap guards run here so a quiet call never starts python; any failure exits 0 silently.
# AGENT_SKILLS_CONTEXT_WINDOW overrides the window (200k, or 1M when the model setting ends in [1m]); AGENT_SKILLS_HANDOFF_PCT the threshold (50).
set -u

input=$(cat 2>/dev/null) || exit 0
lead=$(printf '%.4096s' "$input")
field() {
  rest=${lead#*\"$1\"}
  if [ "$rest" = "$lead" ]; then
    printf '%s' "$input" | grep -o "\"$1\" *: *\"[^\"]*\"" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/'
    return
  fi
  rest=${rest#*\"}
  printf '%s' "${rest%%\"*}"
}

sid=$(field session_id)
[ -n "$sid" ] || exit 0
case $sid in *[!A-Za-z0-9._-]*) exit 0 ;; esac
tmp=${TMPDIR:-/tmp}; tmp=${tmp%/}
[ -e "$tmp/agent-skills-nudge-$sid" ] && exit 0

if [ "$(field hook_event_name)" = PostToolUse ]; then
  throttle="$tmp/agent-skills-nudge-check-$sid"
  now=$(date +%s)
  last=0
  [ -r "$throttle" ] && read -r last < "$throttle"
  case $last in ''|*[!0-9]*) last=0 ;; esac
  [ $((now - last)) -lt 60 ] && exit 0
  printf '%s\n' "$now" > "$throttle" 2>/dev/null || exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0

py=$(cat <<'PY'
import json, os, re, sys, time

MSG = ("Context ≈{p}% used (estimate). Run /handoff (or /agent-skills:handoff) "
       "and start a fresh session before auto-compact summarises this one.")
CTX = ("Context is ≈{p}% used. Suggest the user run /handoff now and continue in a "
       "fresh session instead of relying on compaction; keep answers short until they decide.")
USED_KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")


def window(cwd):
    env = os.environ.get("AGENT_SKILLS_CONTEXT_WINDOW", "")
    if env.isdigit() and int(env) > 0:
        return int(env)
    for path in (os.path.join(cwd, ".claude", "settings.local.json"),
                 os.path.join(cwd, ".claude", "settings.json"),
                 os.path.expanduser("~/.claude/settings.json")):
        try:
            with open(path) as f:
                model = json.load(f).get("model")
        except (OSError, ValueError, AttributeError):
            continue
        if isinstance(model, str):
            return 1_000_000 if model.endswith("[1m]") else 200_000
    return 200_000


def statusline_pct(tmp, sid):
    try:
        with open(f"{tmp}/agent-skills-ctx-{sid}") as f:
            epoch, pct = f.read().split()[:2]
        age = time.time() - int(epoch)
        if 0 <= age <= 120 and 0 <= int(pct) <= 100:
            return int(pct)
    except (OSError, ValueError):
        pass
    return None


def transcript_used(path):
    with open(path, "rb") as f:
        f.seek(0, 2)
        f.seek(max(0, f.tell() - 4 * 1024 * 1024))
        lines = f.read().split(b"\n")
    for line in reversed(lines):
        if b'"usage"' not in line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        if rec.get("type") != "assistant" or rec.get("isSidechain"):
            continue
        usage = (rec.get("message") or {}).get("usage")
        if isinstance(usage, dict):
            return sum(int(usage.get(k) or 0) for k in USED_KEYS)
    return None


def main():
    d = json.load(sys.stdin)
    sid = str(d["session_id"])
    if not re.fullmatch(r"[A-Za-z0-9._-]+", sid):
        return
    event = d.get("hook_event_name") or "UserPromptSubmit"
    tmp = (os.environ.get("TMPDIR") or "/tmp").rstrip("/") or "/tmp"
    guard = f"{tmp}/agent-skills-nudge-{sid}"
    if os.path.exists(guard):
        return
    threshold = int(os.environ.get("AGENT_SKILLS_HANDOFF_PCT") or 50)
    pct = statusline_pct(tmp, sid)
    if pct is None:
        used = transcript_used(d["transcript_path"])
        if used is None:
            return
        pct = min(100, used * 100 // window(d.get("cwd") or os.getcwd()))
    if pct < threshold:
        return
    open(guard, "w").close()
    print(json.dumps({"systemMessage": MSG.format(p=pct),
                      "hookSpecificOutput": {"hookEventName": event,
                                             "additionalContext": CTX.format(p=pct)}}))


try:
    main()
except Exception:
    pass
PY
)
printf '%s' "$input" | python3 -c "$py" 2>/dev/null || exit 0
exit 0
