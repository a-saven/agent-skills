#!/bin/sh
# crew-cost tests against the synthetic session in tests/fixtures/crew-cost. No API, no network.
# Hand-computed expectations: see the fixture's usage blocks; duplicate message ids count once (last record).
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
cc="$root/bin/crew-cost"
fx="$root/tests/fixtures/crew-cost"
main="$fx/session.jsonl"

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
fail=0
pass() { echo "PASS  $1"; }
flunk() { echo "FAIL  $1"; [ -n "${2:-}" ] && echo "      got: $2"; fail=1; }
expect_has() { case $2 in *"$3"*) pass "$1" ;; *) flunk "$1" "$2" ;; esac; }
expect_lacks() { case $2 in *"$3"*) flunk "$1" "$2" ;; *) pass "$1" ;; esac; }
row() { printf '%s\n' "$2" | grep -E "^$1 +\|" || true; }

touch "$work/before"
out=$("$cc" "$main"); rc=$?
[ "$rc" -eq 0 ] && pass "table: exit 0" || flunk "table: exit 0" "rc=$rc"
[ -z "$(find "$fx" -newer "$work/before")" ] && pass "table: writes nothing under the fixture" || flunk "table: wrote files" "$(find "$fx" -newer "$work/before")"
case $out in *"agent "*"| "*"runs |"*"input | cache_write |  cache_read |"*"output |"*"total"*) pass "table: header columns" ;; *) flunk "table: header columns" "$out" ;; esac
r=$(row backend-investigator "$out")
case $r in *"|           2 |"*"410 |"*"4,000 |"*"1,000 |"*"200 |"*"5,610"*) pass "table: backend-investigator = 2 runs, 410/4,000/1,000/200 = 5,610" ;; *) flunk "table: backend-investigator row" "$r" ;; esac
expect_lacks "table: backend-investigator is not partial" "$r" partial
r=$(row frontend-investigator "$out")
case $r in *"|           1 |"*"220 |"*"2,000 |"*"2,000 |"*"150 |"*"4,370  partial"*) pass "table: frontend-investigator = 1 run, 4,370, partial (truncated last line)" ;; *) flunk "table: frontend-investigator row" "$r" ;; esac
r=$(row unknown "$out")
case $r in *"|           1 |"*"44 |"*"400 |"*"400 |"*"6 |"*"850"*) pass "table: unattributed child lands in unknown = 850 (its own tokens only)" ;; *) flunk "table: unknown row" "$r" ;; esac
r=$(row backend-reviewer "$out")
case $r in *"|           1 |"*"30 |"*"500 |"*"0 |"*"12 |"*"542"*) pass "table: grandchild spawned from a child transcript lands under its subagent_type = 542" ;; *) flunk "table: backend-reviewer (grandchild) row" "$r" ;; esac
expect_lacks "table: grandchild is not partial" "$r" partial
expect_lacks "table: meta.json agentType does not rename the unknown row" "$out" workflow-subagent
r=$(row manual-qa "$out")
case $r in *"|           1 |"*"| "*"0 |"*"0  partial"*) pass "table: missing child transcript = 1 run, 0 tokens, partial" ;; *) flunk "table: manual-qa row" "$r" ;; esac
expect_lacks "table: Agent call whose result has no agentId adds no row" "$out" Explore
expect_lacks "table: meta.json naming general-purpose loses to the Agent call's subagent_type" "$out" general-purpose
first=$(printf '%s\n' "$out" | grep -n -E '^(backend|frontend)-investigator' | head -n 1)
case $first in 4:backend*) pass "table: rows sort by total, largest first" ;; *) flunk "table: sort order" "$first" ;; esac
r=$(row claude-haiku-4-5-20251001 "$out")
case $r in *"630 |"*"6,000 |"*"3,000 |"*"350 |"*"9,980"*) pass "table: haiku = the three investigator children = 9,980" ;; *) flunk "table: haiku row" "$r" ;; esac
r=$(row claude-fable-5-1 "$out")
case $r in *"95 |"*"1,050 |"*"1,000 |"*"118 |"*"2,263"*) pass "table: fable = main thread + unknown child + its grandchild = 2,263" ;; *) flunk "table: fable row" "$r" ;; esac
expect_has "table: says per-model totals include main thread and subagents" "$out" "main thread + subagents"
r=$(row "main thread" "$out")
case $r in *"21 |"*"150 |"*"600 |"*"100 |"*"871"*) pass "table: main thread = 21/150/600/100 = 871 (last record per message id wins)" ;; *) flunk "table: main thread row" "$r" ;; esac
expect_lacks "table: main thread is not partial" "$r" partial
expect_has "table: unattributed subagents: 1" "$out" "unattributed subagents: 1"
expect_lacks "table: zero-token <synthetic> records add no model row" "$out" synthetic
expect_lacks "table: no prices" "$out" '$'

"$cc" "$main" --json > "$work/out.json"; rc=$?
[ "$rc" -eq 0 ] && pass "json: exit 0" || flunk "json: exit 0" "rc=$rc"
if python3 - "$work/out.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
a, m = d["agents"], d["models"]
assert a["backend-investigator"] == dict(runs=2, input=410, cache_write=4000, cache_read=1000, output=200, total=5610, partial=False), a
assert a["frontend-investigator"] == dict(runs=1, input=220, cache_write=2000, cache_read=2000, output=150, total=4370, partial=True), a
assert a["unknown"] == dict(runs=1, input=44, cache_write=400, cache_read=400, output=6, total=850, partial=False), a
assert a["backend-reviewer"] == dict(runs=1, input=30, cache_write=500, cache_read=0, output=12, total=542, partial=False), a
assert a["manual-qa"] == dict(runs=1, input=0, cache_write=0, cache_read=0, output=0, total=0, partial=True), a
assert set(a) == {"backend-investigator", "frontend-investigator", "backend-reviewer", "unknown", "manual-qa"}, a
assert m["claude-haiku-4-5-20251001"] == dict(input=630, cache_write=6000, cache_read=3000, output=350, total=9980), m
assert m["claude-fable-5-1"] == dict(input=95, cache_write=1050, cache_read=1000, output=118, total=2263), m
assert set(m) == {"claude-haiku-4-5-20251001", "claude-fable-5-1"}, m
assert d["main"] == dict(input=21, cache_write=150, cache_read=600, output=100, total=871, partial=False), d["main"]
assert d["unattributed"] == 1, d
assert d["transcript"].endswith("session.jsonl"), d
PY
then pass "json: exact totals, runs, partial flags and unattributed count"; else flunk "json: exact totals"; fi

out=$("$cc" --help); rc=$?
[ "$rc" -eq 0 ] && pass "help: exit 0" || flunk "help: exit 0" "rc=$rc"
expect_has "help: labels the default-transcript rule as observed" "$out" observed
expect_has "help: says counts only, no prices" "$out" "no prices"
out=$("$cc" --bogus 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "unknown flag: exit 2 with usage" || flunk "unknown flag: exit 2" "rc=$rc $out"
out=$("$cc" "$work/missing.jsonl" 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "missing transcript path: non-zero exit" || flunk "missing transcript path" "rc=$rc $out"
expect_has "missing transcript path: names the file" "$out" "missing.jsonl"

proj="$work/proj"; mkdir -p "$proj"; real=$(cd "$proj" && pwd -P)
out=$(cd "$proj" && HOME="$work/home" "$cc" 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "discovery: no project dir under HOME exits non-zero" || flunk "discovery: no project dir" "rc=$rc $out"
expect_has "discovery: says no transcript found; pass the path" "$out" "no transcript found"
expect_has "discovery: names the encoded project dir" "$out" "$(printf '%s' "$real" | tr / -)"
pdir="$work/home/.claude/projects/$(printf '%s' "$real" | tr / -)"; mkdir -p "$pdir"
printf '{"type":"user","message":{"role":"user","content":"old"}}\n' > "$pdir/older.jsonl"
touch -t 202001010000 "$pdir/older.jsonl"
cp "$main" "$pdir/newer.jsonl"; cp -R "$fx/session" "$pdir/newer"
out=$(cd "$proj" && HOME="$work/home" "$cc"); rc=$?
[ "$rc" -eq 0 ] && pass "discovery: newest *.jsonl under the encoded cwd is used" || flunk "discovery: exit" "rc=$rc"
expect_has "discovery: picked newer.jsonl" "$out" "newer.jsonl"
expect_has "discovery: found its subagents dir (backend row present)" "$out" "backend-investigator"

cp "$main" "$work/bad.jsonl"; cp -R "$fx/session" "$work/bad"
printf 'null\n{"type":"assistant","uuid":"x9","message":{"id":"msg_bad","model":"claude-fable-5-1","usage":{"input_tokens":"many","output_tokens":1}}}\n' >> "$work/bad.jsonl"
out=$("$cc" "$work/bad.jsonl"); rc=$?
[ "$rc" -eq 0 ] && pass "malformed: null record and string token count do not crash" || flunk "malformed: exit" "rc=$rc $out"
r=$(row "main thread" "$out"); expect_has "malformed: main thread row is marked partial" "$r" partial

echo
[ "$fail" -eq 0 ] && echo "crew-cost: all cases passed" || echo "crew-cost: FAILURES above"
exit "$fail"
