#!/usr/bin/env bash
# test.sh — the cross-check contract, checked with no LLM in the loop.
#
# That is the point of this phase: the stop rule, the coverage arithmetic and the
# attribution check are all decidable without a model, so they are all testable
# without one. Run it before changing any schema or helper here.
#
#   ./test.sh            run everything
#   ./test.sh -v         also print each command's output
#
# Exit: 0 all pass · 1 any failure.
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

PASS=0; FAIL=0
TMP="$(mktemp -d)" || exit 2
cleanup() {
  [[ -d "$TMP/repo/.git" ]] && git -C "$TMP/repo" worktree prune >/dev/null 2>&1
  rm -rf "$TMP"
}
trap cleanup EXIT

ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }

# expect_exit <want> <label> <cmd...>
expect_exit() {
  local want="$1" label="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  (( VERBOSE )) && printf '        $ %s\n%s\n' "$*" "$out"
  if [[ "$rc" == "$want" ]]; then ok "$label"; else bad "$label" "expected exit $want, got $rc: $(head -1 <<<"$out")"; fi
}

# expect_out <want> <label> <cmd...>
expect_out() {
  local want="$1" label="$2"; shift 2
  local out
  out="$("$@" 2>/dev/null)"
  (( VERBOSE )) && printf '        $ %s\n%s\n' "$*" "$out"
  if [[ "$out" == "$want" ]]; then ok "$label"; else bad "$label" "expected '$want', got '$out'"; fi
}

echo "== stop rule, both directions, from fixtures"
expect_out continue "refuted claim              -> continue" ./crosscheck-decide.sh fixtures/findings-claim-refuted.json
expect_out continue "uncovered scope            -> continue" ./crosscheck-decide.sh fixtures/findings-uncovered-scope.json
expect_out continue "blocker, introduced        -> continue" ./crosscheck-decide.sh fixtures/findings-blocker-introduced.json
expect_out stop     "blocker, pre-existing      -> stop"     ./crosscheck-decide.sh fixtures/findings-blocker-preexisting.json
expect_out stop     "clean                      -> stop"     ./crosscheck-decide.sh fixtures/findings-clean.json
expect_out halt     "continue at the round cap  -> halt"     ./crosscheck-decide.sh fixtures/findings-claim-refuted.json --round 3 --max-rounds 3

echo "== the same input decides the same way every time"
n="$(for _ in 1 2 3; do ./crosscheck-decide.sh fixtures/findings-clean.json; done | sort -u | wc -l)"
[[ "$n" == "1" ]] && ok "three runs, one answer" || bad "three runs, one answer" "got $n distinct answers"

echo "== the verdict field cannot move the decision"
v="$(jq '.verdict="unsound"' fixtures/findings-clean.json > "$TMP/v.json" && ./crosscheck-decide.sh "$TMP/v.json")"
[[ "$v" == "stop" ]] && ok "verdict is advisory only" || bad "verdict is advisory only" "got $v"

echo "== payload validation"
expect_exit 0 "a conforming handoff passes"                  ./validate-payload.sh handoff fixtures/handoff-basic.json --final
expect_exit 1 "incomplete claims_verified[] is rejected"     ./validate-payload.sh findings fixtures/findings-missing-claim.json
expect_exit 1 "over-cap handoff blocks, not truncates"       ./validate-payload.sh handoff fixtures/handoff-oversized.json
jq --arg pad "$(head -c 40000 /dev/zero | tr '\0' 'x')" '.traps += [$pad]' \
   fixtures/handoff-basic.json > "$TMP/fat.json"
expect_exit 1 "a payload that really is too big is measured, not believed" \
  ./validate-payload.sh handoff "$TMP/fat.json"
jq '.budget.est_tokens=1' fixtures/handoff-basic.json > "$TMP/stale.json"
expect_exit 1 "a stale budget that understates the payload is rejected" \
  ./validate-payload.sh handoff "$TMP/stale.json"
jq '.budget.cap=999999' fixtures/handoff-basic.json > "$TMP/bigcap.json"
expect_exit 1 "a payload cannot raise its own cap"           ./validate-payload.sh handoff "$TMP/bigcap.json"
jq '.budget.cap=999999' fixtures/findings-clean.json > "$TMP/bigcapf.json"
expect_exit 1 "nor can a findings payload"                   ./validate-payload.sh findings "$TMP/bigcapf.json" --handoff fixtures/handoff-basic.json
expect_exit 1 "accepted-deferred with no detail is rejected" ./validate-payload.sh disposition fixtures/disposition-deferred-no-detail.json
expect_exit 1 "rejected with no rebuttal is rejected"        ./validate-payload.sh disposition fixtures/disposition-rejected-no-detail.json
expect_exit 1 "an undisposed finding is rejected"            ./validate-payload.sh disposition fixtures/disposition-missing-finding.json
expect_exit 0 "a conforming disposition passes"              ./validate-payload.sh disposition fixtures/disposition-clean.json

for f in fixtures/findings-clean.json fixtures/findings-blocker-introduced.json \
         fixtures/findings-blocker-preexisting.json fixtures/findings-claim-refuted.json \
         fixtures/findings-uncovered-scope.json; do
  expect_exit 0 "conforming: $(basename "$f")" ./validate-payload.sh findings "$f"
done

echo "== a mechanical claim with no runnable check is not a claim"
jq 'del(.claims[0].check)' fixtures/handoff-basic.json > "$TMP/nocheck.json"
expect_exit 1 "mechanical claim without check"  ./validate-payload.sh handoff "$TMP/nocheck.json"
jq '.claims[2].check={"type":"count-eq"}' fixtures/handoff-basic.json > "$TMP/noval.json"
expect_exit 1 "count-eq check without a value"  ./validate-payload.sh handoff "$TMP/noval.json"

echo "== coverage is arithmetic, not opinion"
out="$(./crosscheck-coverage.sh --handoff fixtures/handoff-partial.json --changed fixtures/changed-partial.txt 2>&1)"
if grep -q 'scripts/release.sh' <<<"$out" && grep -q 'uncovered=1' <<<"$out"; then
  ok "names the one unclaimed file"
else
  bad "names the one unclaimed file" "$out"
fi

# ── a real repository, for the git-backed halves ─────────────────────────────
echo "== against a real repository"
R="$TMP/repo"
mkdir -p "$R/scripts" "$R/docs"
git -C "$R" init -q -b main
git -C "$R" config user.email crosscheck@example.invalid
git -C "$R" config user.name  crosscheck-test
printf 'exit 0\n' > "$R/scripts/lint.sh"
printf 'base\n'   > "$R/docs/a.md"
git -C "$R" add -A && git -C "$R" commit -qm base
BASE="$(git -C "$R" rev-parse HEAD)"
printf 'published\n' > "$R/scripts/release.sh"
printf 'new\n'       > "$R/docs/b.md"
git -C "$R" add -A && git -C "$R" commit -qm work
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"

expect_out introduced-by-change "attribution: introduced" \
  ./crosscheck-attribute.sh --repo "$R" --base "$BASE" --head "$HEAD_SHA" --cmd 'test -f scripts/release.sh'
expect_out pre-existing "attribution: pre-existing" \
  ./crosscheck-attribute.sh --repo "$R" --base "$BASE" --head "$HEAD_SHA" --cmd 'test -f scripts/lint.sh'
expect_out not-a-defect "attribution: not-a-defect" \
  ./crosscheck-attribute.sh --repo "$R" --base "$BASE" --head "$HEAD_SHA" --cmd 'test -f never-existed'
expect_exit 3 "attribution: unreachable repo is inconclusive, not a guess" \
  ./crosscheck-attribute.sh --repo "$TMP/not-a-repo" --base "$BASE" --head "$HEAD_SHA" --cmd 'true'

echo "== the append helper"
export CROSSCHECK_DIR="$TMP/payloads"
export CROSSCHECK_SESSION="test-session"
H="$(./crosscheck-claim open --repo "$R" --policy-key example_app --clearance medium \
      --base "$BASE" --agent alpha --provider cli-a --model model-a-1 2>&1)"
if [[ -r "$H" ]]; then ok "open writes a conforming handoff"; else bad "open writes a conforming handoff" "$H"; fi

expect_exit 1 "a mechanical claim whose check fails at write time is refused" \
  ./crosscheck-claim add --class mechanical --statement x --evidence-cmd 'false' --check exit0
expect_exit 1 "a mechanical claim with no check is refused" \
  ./crosscheck-claim add --class mechanical --statement x --evidence-cmd 'true'
expect_exit 0 "a runnable mechanical claim is accepted" \
  ./crosscheck-claim add --statement "the linter exits clean" --evidence-cmd 'true' \
    --check exit0 --files scripts/lint.sh
expect_exit 0 "a judgment claim needs no check" \
  ./crosscheck-claim add --statement "the rename preserves meaning" --files docs/a.md
./crosscheck-claim trap "the linter only ever acts on the first roots entry" >/dev/null
expect_exit 0 "the accumulated payload validates" ./validate-payload.sh handoff "$H"

echo "== the loop finds what was never claimed"
out="$(./crosscheck-coverage.sh --handoff "$H" --write --strict 2>&1)"; rc=$?
if [[ $rc -eq 10 ]] && grep -q 'scripts/release.sh' <<<"$out"; then
  ok "an unclaimed changed file is named, not noticed"
else
  bad "an unclaimed changed file is named, not noticed" "rc=$rc $out"
fi

echo "== mechanical claims are run before the reviewer is spawned"
./crosscheck-run-checks.sh --handoff "$H" >/dev/null 2>&1
n="$(jq -r '[.check_results[] | select(.ran and .matched)] | length' "$H")"
[[ "$n" == "1" ]] && ok "the one mechanical claim was executed and matched" \
                  || bad "the one mechanical claim was executed and matched" "got $n"

echo "== a machine check overrides the reviewer's attribution, in both directions"
jq --arg h "$H" --arg r "$R" '
   .handoff_ref = $h | .findings[0].repo = $r
 | .findings[0].repro_cmd = "test -f scripts/release.sh"
 | .findings[0].attribution = "pre-existing"
 | del(.findings[0].attribution_checked)' fixtures/findings-blocker-preexisting.json > "$TMP/mis.json"
./crosscheck-attribute.sh --findings "$TMP/mis.json" --handoff "$H" --write >/dev/null 2>&1
expect_out continue "a mis-claimed pre-existing blocker continues the loop" \
  ./crosscheck-decide.sh "$TMP/mis.json"

jq --arg h "$H" --arg r "$R" '
   .handoff_ref = $h | .findings[0].repo = $r
 | .findings[0].repro_cmd = "test -f scripts/lint.sh"
 | .findings[0].attribution = "introduced-by-change"
 | del(.findings[0].attribution_checked)' fixtures/findings-blocker-introduced.json > "$TMP/gen.json"
./crosscheck-attribute.sh --findings "$TMP/gen.json" --handoff "$H" --write >/dev/null 2>&1
expect_out stop "a genuinely pre-existing blocker stops the loop" \
  ./crosscheck-decide.sh "$TMP/gen.json"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
