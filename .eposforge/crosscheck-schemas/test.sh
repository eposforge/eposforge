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

echo "== scope integrity: a pull can invalidate a handoff nobody rewrote"
expect_exit 0 "freshly opened scope verifies clean" \
  ./crosscheck-verify-scope.sh --handoff "$H" --write --quiet

# Reproduce the real failure exactly: an upstream commit lands and an ordinary
# `git pull --rebase` replays the unpushed local commit onto it. The replacement
# carries a byte-identical subject line, which is why nobody notices.
UP="$TMP/upstream"
git clone -q --bare "$R" "$UP"
git -C "$R" remote add origin "$UP" 2>/dev/null
printf 'unrelated upstream work\n' > "$R/docs/upstream.md"
git -C "$R" add -A && git -C "$R" commit -qm "post"
git -C "$R" push -q origin main
git -C "$R" reset -q --hard HEAD~1                       # local no longer has it
printf 'local work\n' > "$R/docs/local.md"
git -C "$R" add -A && git -C "$R" commit -qm "backlog: a local commit"
ORPHAN="$(git -C "$R" rev-parse HEAD)"

./crosscheck-claim scope --repo "$R" --policy-key example_app --clearance medium --base "$BASE" >/dev/null
expect_exit 0 "verifies clean before the pull" \
  ./crosscheck-verify-scope.sh --handoff "$H" --write --quiet

git -C "$R" -c pull.rebase=true -c rebase.autoStash=true pull -q origin main 2>/dev/null
REPLACEMENT="$(git -C "$R" rev-parse HEAD)"

if [[ "$ORPHAN" != "$REPLACEMENT" ]]; then ok "the pull did rebase the local commit"
else bad "the pull did rebase the local commit" "sha unchanged; test setup did not reproduce it"; fi

expect_exit 10 "scope drift is detected after the pull" \
  ./crosscheck-verify-scope.sh --handoff "$H" --quiet
out="$(./crosscheck-verify-scope.sh --handoff "$H" 2>&1)"
if grep -q 'head-orphaned' <<<"$out" && grep -q 'SAME subject' <<<"$out"; then
  ok "names it head-orphaned and points at the identical-subject replacement"
else
  bad "names it head-orphaned and points at the identical-subject replacement" "$out"
fi

./crosscheck-verify-scope.sh --handoff "$H" --write --quiet >/dev/null 2>&1 || true
expect_exit 1 "a drifted payload cannot be finalised" ./validate-payload.sh handoff "$H" --final
jq '.scope |= map(del(.integrity))' "$H" > "$TMP/unverified.json"
expect_exit 1 "an unverified payload cannot be finalised either" \
  ./validate-payload.sh handoff "$TMP/unverified.json" --final

# Put the scope back on the branch so the remaining tests work against a sane payload.
./crosscheck-claim scope --repo "$R" --policy-key example_app --clearance medium --base "$BASE" >/dev/null
expect_exit 0 "re-scoping after the drift verifies clean again" \
  ./crosscheck-verify-scope.sh --handoff "$H" --write --quiet

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

echo "== reviewer-supplied commands do not run just because they arrived"
jq --arg h "$H" --arg r "$R" '
   .handoff_ref = $h | .findings[0].repo = $r
 | .findings[0].repro_cmd = "touch \"'"$TMP"'/EXECUTED\"; exit 0"
 | del(.findings[0].attribution_checked)' fixtures/findings-blocker-introduced.json > "$TMP/hostile.json"
expect_exit 4 "refuses foreign repro_cmd without --allow-reviewer-exec" \
  ./crosscheck-attribute.sh --findings "$TMP/hostile.json" --handoff "$H"
if [[ -e "$TMP/EXECUTED" ]]; then bad "the refusal actually prevented execution" "the command ran anyway"
else ok "the refusal actually prevented execution"; fi
out="$(./crosscheck-attribute.sh --findings "$TMP/hostile.json" --handoff "$H" 2>&1)"
grep -q 'touch' <<<"$out" && ok "prints the command so consent is informed" \
                          || bad "prints the command so consent is informed" "$out"
./crosscheck-attribute.sh --findings "$TMP/hostile.json" --handoff "$H" --allow-reviewer-exec >/dev/null 2>&1
if [[ -e "$TMP/EXECUTED" ]]; then ok "runs it once the operator opts in"
else bad "runs it once the operator opts in" "still did not run"; fi

echo "== a hung command cannot hang the loop"
jq '.claims=[{"id":"c1",class:"mechanical",statement:"x",evidence_cmd:"sleep 60",
     check:{type:"exit0"},files:[]}] | .check_results=[]' "$H" > "$TMP/slow.json"
start=$SECONDS
./crosscheck-run-checks.sh --handoff "$TMP/slow.json" --out-dir "$TMP" --cwd "$R" --timeout 2 >/dev/null 2>&1
took=$(( SECONDS - start ))
if (( took < 20 )); then ok "timed out after ${took}s instead of running to completion"
else bad "timed out after ${took}s instead of running to completion" "no timeout applied"; fi

echo "== the harness's answer beats the reviewer's on anything the harness decided"
jq '.check_results=[{claim_id:"c1",ran:true,exit_code:1,matched:false,output_ref:"x"},
                    {claim_id:"c3",ran:true,exit_code:0,matched:true,output_ref:"y"}]' \
   fixtures/handoff-basic.json > "$TMP/failedcheck.json"
jq --arg h "$TMP/failedcheck.json" '.handoff_ref=$h' fixtures/findings-clean.json > "$TMP/fc.json"
expect_out continue "a failed mechanical check keeps the loop open even when the reviewer confirmed it" \
  ./crosscheck-decide.sh "$TMP/fc.json"

echo "== payloads cannot be parked somewhere committable"
CROSSCHECK_DIR="$R/.crosscheck" CROSSCHECK_SESSION=in-repo \
  expect_exit 2 "refuses a payload directory inside a git work tree" \
  ./crosscheck-claim open --repo "$R" --clearance low

echo "== rounds must line up"
jq '.round=99' fixtures/findings-clean.json > "$TMP/r99.json"
expect_exit 1 "round-99 findings are rejected against a round-1 handoff" \
  ./validate-payload.sh findings "$TMP/r99.json" --handoff fixtures/handoff-basic.json
jq '.round=2 | del(.disposition_ref)' fixtures/handoff-basic.json > "$TMP/r2.json"
expect_exit 1 "round 2 without a disposition_ref cannot be finalised" \
  ./validate-payload.sh handoff "$TMP/r2.json" --final

echo "== mechanical claims run in the repo they are about, not in scope[0]"
RA="$TMP/repo-a"; RB="$TMP/repo-b"
mkdir -p "$RA" "$RB"
git -C "$RA" init -q -b main; git -C "$RA" config user.email t@e.invalid; git -C "$RA" config user.name t
git -C "$RB" init -q -b main; git -C "$RB" config user.email t@e.invalid; git -C "$RB" config user.name t
echo x >"$RA/f"; git -C "$RA" add -A && git -C "$RA" commit -qm a
echo y >"$RB/unique2.txt"; git -C "$RB" add -A && git -C "$RB" commit -qm b
AH="$(git -C "$RA" rev-parse HEAD)"; BH="$(git -C "$RB" rev-parse HEAD)"
# The Phase 0 reviewer's repro: two-repo handoff, unique2.txt only in repo 2,
# evidence_cmd is a relative test, files[] names that path, no cwd field.
jq -n --arg a "$RA" --arg b "$RB" --arg ah "$AH" --arg bh "$BH" \
  '{schema:"eposforge.crosscheck.handoff/1",round:1,session:"x",
    implementer:{agent:"a",provider:"p",model:"m"},
    scope:[
      {repo_path:$a,policy_key:"a",clearance:"low",base_sha:$ah,head_sha:$ah,dirty:false},
      {repo_path:$b,policy_key:"b",clearance:"low",base_sha:$bh,head_sha:$bh,dirty:false}
    ],
    clearance_required:"low",
    claims:[{id:"c1",class:"mechanical",statement:"u2",evidence_cmd:"test -f unique2.txt",
             check:{type:"exit0"},files:["unique2.txt"]}],
    traps:[],attack_first:[],out_of_scope:[],ground_rules:[],
    budget:{est_tokens:1,rendered_bytes:4,cap:8000,over_budget:false}}' >"$TMP/two.json"
./crosscheck-run-checks.sh --handoff "$TMP/two.json" --out-dir "$TMP/two" >/dev/null 2>&1
expect_out true "files[] in repo 2 is not executed in scope[0]" \
  jq -r '.check_results[0].matched' "$TMP/two.json"
got_cwd="$(jq -r '.check_results[0].cwd // empty' "$TMP/two.json")"
if [[ "$got_cwd" == "$(cd "$RB" && pwd -P)" ]]; then ok "records the resolved cwd as repo 2"
else bad "records the resolved cwd as repo 2" "got '$got_cwd'"; fi

jq '.claims[0].files=[] | del(.claims[0].cwd) | .check_results=[]' "$TMP/two.json" >"$TMP/two-bare.json"
./crosscheck-run-checks.sh --handoff "$TMP/two-bare.json" --out-dir "$TMP/two-bare" >/dev/null 2>&1
expect_out false "multi-repo with no cwd and no files is refused, not run in scope[0]" \
  jq -r '.check_results[0].matched' "$TMP/two-bare.json"

# add must probe in the resolved repo, not refuse a true exit0 about repo 2
export CROSSCHECK_DIR="$TMP/payloads-two" CROSSCHECK_SESSION="two-repo-add"
H2="$(./crosscheck-claim open --repo "$RA" --policy-key a --clearance low --agent a --provider p --model m 2>&1)"
./crosscheck-claim scope --repo "$RB" --policy-key b --clearance low >/dev/null
expect_exit 0 "add accepts an exit0 claim that is only true in a later repo" \
  ./crosscheck-claim add --statement u2 --evidence-cmd 'test -f unique2.txt' \
    --check exit0 --files unique2.txt
expect_exit 1 "add still refuses an exit0 claim that is false in its resolved repo" \
  ./crosscheck-claim add --statement missing --evidence-cmd 'test -f no-such-file' \
    --check exit0 --cwd "$RB"

echo "== count-eq parses an integer token, not every digit on the line"
jq --arg r "$R" --arg h "$HEAD_SHA" --arg b "$BASE" \
  '.scope=[{repo_path:$r,policy_key:"example_app",clearance:"low",base_sha:$b,head_sha:$h,dirty:false}]
   | .claims=[{id:"c1",class:"mechanical",statement:"x",
               evidence_cmd:"printf \"58 passed, 0 failed\\n\"",
               check:{type:"count-eq",value:580},files:[]}]
   | .check_results=[]' "$H" >"$TMP/cnt-strip.json"
./crosscheck-run-checks.sh --handoff "$TMP/cnt-strip.json" --out-dir "$TMP/cnt-strip" >/dev/null 2>&1
expect_out false "58 passed, 0 failed is not the number 580" \
  jq -r '.check_results[0].matched' "$TMP/cnt-strip.json"
jq '.claims[0].evidence_cmd="printf \"58\\n\"" | .claims[0].check.value=58 | .check_results=[]' \
  "$TMP/cnt-strip.json" >"$TMP/cnt-ok.json"
./crosscheck-run-checks.sh --handoff "$TMP/cnt-ok.json" --out-dir "$TMP/cnt-ok" >/dev/null 2>&1
expect_out true "a bare 58 matches count-eq:58" \
  jq -r '.check_results[0].matched' "$TMP/cnt-ok.json"

echo "== regex is jq/Oniguruma over the whole output"
jq '.claims=[{id:"c1",class:"mechanical",statement:"x",
              evidence_cmd:"printf hello",
              check:{type:"regex",value:"(?i)HELLO"},files:[]}]
    | .check_results=[]' "$TMP/cnt-strip.json" >"$TMP/re.json"
./crosscheck-run-checks.sh --handoff "$TMP/re.json" --out-dir "$TMP/re" >/dev/null 2>&1
expect_out true "(?i)HELLO matches hello via jq test" \
  jq -r '.check_results[0].matched' "$TMP/re.json"

echo "== dirty-tree coverage parses porcelain renames and untracked files"
RD="$TMP/repo-dirty"
mkdir -p "$RD/d"
git -C "$RD" init -q -b main
git -C "$RD" config user.email t@e.invalid
git -C "$RD" config user.name t
echo x >"$RD/d/old.md"
echo keep >"$RD/keep.md"
git -C "$RD" add -A && git -C "$RD" commit -qm base
RDBASE="$(git -C "$RD" rev-parse HEAD)"
git -C "$RD" mv d/old.md d/new.md
mkdir -p "$RD/newdir"
echo z >"$RD/newdir/f.txt"
jq -n --arg r "$RD" --arg h "$RDBASE" \
  '{schema:"eposforge.crosscheck.handoff/1",round:1,session:"d",
    implementer:{agent:"a",provider:"p",model:"m"},
    scope:[{repo_path:$r,policy_key:"d",clearance:"low",base_sha:$h,head_sha:$h,dirty:true}],
    clearance_required:"low",
    claims:[
      {id:"c1",class:"mechanical",statement:"renamed",evidence_cmd:"true",check:{type:"exit0"},files:["d/new.md"]},
      {id:"c2",class:"mechanical",statement:"untracked",evidence_cmd:"true",check:{type:"exit0"},files:["newdir/f.txt"]}
    ],
    traps:[],attack_first:[],out_of_scope:[],ground_rules:[],
    budget:{est_tokens:1,rendered_bytes:4,cap:8000,over_budget:false}}' >"$TMP/dirty.json"
out="$(./crosscheck-coverage.sh --handoff "$TMP/dirty.json" 2>&1)"
if grep -q 'old.md -> new.md' <<<"$out"; then
  bad "a rename is not the single path 'old -> new'" "$out"
else
  ok "a rename is not the single path 'old -> new'"
fi
if grep -q 'newdir/f.txt' <<<"$out"; then
  bad "an untracked file named in files[] is covered" "$out"
else
  ok "an untracked file named in files[] is covered"
fi
# The old path of the rename is a changed file and is unclaimed — that is
# honest set arithmetic. It must appear as its own path, not glued to the new.
if grep -qE 'd/old\.md$' <<<"$out"; then
  ok "the rename's old path is listed separately"
else
  bad "the rename's old path is listed separately" "$out"
fi

echo "== --findings EXIT trap still removes the worktree"
# The previous trap replacement dropped cleanup_worktree from EXIT. Compose,
# don't replace: a single EXIT trap must still call cleanup.
if grep -q 'cleanup_all' ./crosscheck-attribute.sh \
   && ! grep -n "trap " ./crosscheck-attribute.sh | grep -qv cleanup; then
  ok "attribute EXIT trap still includes worktree cleanup"
else
  bad "attribute EXIT trap still includes worktree cleanup" \
    "$(grep -n 'trap ' ./crosscheck-attribute.sh)"
fi

echo "== a machine check overrides the reviewer's attribution, in both directions"
jq --arg h "$H" --arg r "$R" '
   .handoff_ref = $h | .findings[0].repo = $r
 | .findings[0].repro_cmd = "test -f scripts/release.sh"
 | .findings[0].attribution = "pre-existing"
 | del(.findings[0].attribution_checked)' fixtures/findings-blocker-preexisting.json > "$TMP/mis.json"
./crosscheck-attribute.sh --findings "$TMP/mis.json" --handoff "$H" --write --allow-reviewer-exec >/dev/null 2>&1
expect_out continue "a mis-claimed pre-existing blocker continues the loop" \
  ./crosscheck-decide.sh "$TMP/mis.json"

jq --arg h "$H" --arg r "$R" '
   .handoff_ref = $h | .findings[0].repo = $r
 | .findings[0].repro_cmd = "test -f scripts/lint.sh"
 | .findings[0].attribution = "introduced-by-change"
 | del(.findings[0].attribution_checked)' fixtures/findings-blocker-introduced.json > "$TMP/gen.json"
./crosscheck-attribute.sh --findings "$TMP/gen.json" --handoff "$H" --write --allow-reviewer-exec >/dev/null 2>&1
expect_out stop "a genuinely pre-existing blocker stops the loop" \
  ./crosscheck-decide.sh "$TMP/gen.json"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
