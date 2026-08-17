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
# The revision immediately BEFORE --json-errors existed, pinned by SHA so the
# "human output is unchanged" case compares against a fixed point rather than
# against whatever HEAD~ happens to be (eposforge:EF-079). A clone that does not
# have this commit — shallow, or a vendored copy — skips that one case and says
# so, rather than passing silently for want of a comparison.
PRE_079_SHA="6cfb1af21c02c1cffb0831d2edbf461a10b46bde"
SCRIPT_DIR_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
# Do not inherit the caller's session. These checks are themselves run by
# `crosscheck-run-checks.sh` during a finalize, which exports CROSSCHECK_ROUND
# and CROSSCHECK_SESSION — and a fixture that assumes round-1 paths then fails
# for a reason that has nothing to do with the contract. A suite that only
# passes in a clean shell is a suite that will mislead somebody.
export CROSSCHECK_ROUND=1
unset CROSSCHECK_SESSION
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

echo "== invalid splits into shape-only (3) and substantive (1)"
# The whole point of the split: 3 says a caller MAY re-ask the reviewer once, 1
# says it may not. Get this backwards in either direction and the loop either
# throws away good reviews or retries its way past a missing verdict.
expect_exit 3 "a renamed property alone is shape-only" \
  ./validate-payload.sh findings fixtures/findings-renamed-property.json --handoff fixtures/handoff-basic.json
expect_exit 1 "a missing claim verdict is substantive, never shape-only" \
  ./validate-payload.sh findings fixtures/findings-missing-claim.json --handoff fixtures/handoff-basic.json
expect_exit 1 "shape AND substance together is substantive — the shape error must not launder the missing verdict" \
  ./validate-payload.sh findings fixtures/findings-renamed-and-missing-claim.json --handoff fixtures/handoff-basic.json
expect_exit 0 "a conforming findings payload is unaffected by the split" \
  ./validate-payload.sh findings fixtures/findings-clean.json --handoff fixtures/handoff-basic.json
# An over-budget payload is about content, not shape: no re-ask.
jq '.budget.cap = 10' fixtures/findings-clean.json > "$TMP/overcapf.json"
expect_exit 1 "an over-cap findings payload is substantive, not shape-only" \
  ./validate-payload.sh findings "$TMP/overcapf.json" --handoff fixtures/handoff-basic.json

# Negative control, executed rather than asserted. Cases above are green
# whenever the new fixtures parse; none of them witnesses the classifier
# BREAKING, so on their own they cannot tell a working split from a split that
# never ran. Here the phase tag is removed from a copy and the both-defects
# fixture is re-checked: without it a missing claim verdict misclassifies as
# shape-only, which is precisely the failure the split exists to prevent.
mkdir -p "$TMP/nc"
sed 's/^PHASE=cross$/PHASE=schema/' validate-payload.sh > "$TMP/nc/validate-payload.sh"
chmod +x "$TMP/nc/validate-payload.sh"
ln -s "$PWD/lib" "$TMP/nc/lib"
for _s in handoff findings disposition; do ln -s "$PWD/$_s.v1.json" "$TMP/nc/$_s.v1.json"; done
expect_exit 3 "negative control: with the phase tag removed, a missing verdict misclassifies as shape-only" \
  "$TMP/nc/validate-payload.sh" findings fixtures/findings-renamed-and-missing-claim.json --handoff fixtures/handoff-basic.json
echo "== --json-errors is a second channel, never a second verdict (EF-079)"
# The reason this exists: acting on a validator error used to mean matching the
# English of `unexpected property "X"`. The reason it is dangerous: a machine
# channel is exactly the shape of thing that grows a way to say "close enough".

# 1. The property name is recoverable as a FIELD, with no prose matching at all.
je="$(./validate-payload.sh findings fixtures/findings-renamed-property.json \
        --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"
if [[ "$(jq -r '[.errors[]|select(.keyword=="additionalProperties")|.property]|join(",")' <<<"$je")" == "correct_state" ]]
then ok "the offending property is a distinct field, not embedded in a sentence"
else bad "the offending property is a distinct field" "got: $je"; fi
if [[ "$(jq -r '.errors[0].pointer' <<<"$je")" == "/findings/0" ]]
then ok "and it carries an RFC 6901 pointer to the offending location"
else bad "an RFC 6901 pointer is reported" "got: $(jq -r '.errors[0].pointer' <<<"$je")"; fi

# 2. A substantive failure is reported AS substantive. A caller that re-asks on
#    schema-phase errors must be able to see it was not one, positively, rather
#    than inferring it from an absence.
je="$(./validate-payload.sh findings fixtures/findings-missing-claim.json \
        --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"
if [[ "$(jq -r '[.errors[].phase]|unique|join(",")' <<<"$je")" == *cross* ]]
then ok "a missing claim verdict is tagged phase=cross in the machine form"
else bad "a missing claim verdict is tagged phase=cross" "got: $je"; fi

# 3. THE SAFETY PROPERTY. The flag must not change any verdict, anywhere.
mismatch=0
for _f in fixtures/*.json; do
  for _k in handoff findings disposition; do
    ./validate-payload.sh "$_k" "$_f" >/dev/null 2>&1; _a=$?
    ./validate-payload.sh "$_k" "$_f" --json-errors >/dev/null 2>&1; _b=$?
    [[ "$_a" != "$_b" ]] && mismatch=$((mismatch+1))
  done
done
if (( mismatch == 0 ))
then ok "--json-errors changes no exit code across every fixture x schema"
else bad "--json-errors changes no exit code" "$mismatch mismatches"; fi

# 3b. The re-ask gate EXACTLY as the README tells a caller to write it. Round 1's
#     reviewer refuted the claim that the documented rule was safe: the earlier
#     wording ("no error has phase cross") is vacuously true of an empty list,
#     and an empty list is also what a FAILED machine channel produces, since it
#     fails open. So the documented rule is asserted here rather than trusted,
#     against all three cases a caller can meet.
GATE='(.errors | length) > 0 and all(.errors[]; .phase == "schema")'
gate_says() { jq -e "$GATE" >/dev/null 2>&1 <<<"$1" && echo permit || echo refuse; }

je_shape="$(./validate-payload.sh findings fixtures/findings-renamed-property.json \
             --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"
je_cross="$(./validate-payload.sh findings fixtures/findings-missing-claim.json \
             --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"
je_valid="$(./validate-payload.sh findings fixtures/findings-clean.json \
             --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"

[[ "$(gate_says "$je_shape")" == permit ]] \
  && ok "the documented re-ask gate permits a shape-only failure" \
  || bad "gate permits shape-only" "got $(gate_says "$je_shape")"
[[ "$(gate_says "$je_cross")" == refuse ]] \
  && ok "and refuses a substantive one" \
  || bad "gate refuses substantive" "got $(gate_says "$je_cross")"
# The case the old wording got wrong, and the reason this block exists.
[[ "$(gate_says "$je_valid")" == refuse ]] \
  && ok "and refuses an EMPTY error list, which a broken channel also produces" \
  || bad "gate refuses an empty error list" "an empty list read as re-ask permission"
[[ "$(gate_says '{"errors":[]}')" == refuse ]] \
  && ok "  including a hand-made empty list, so it is the rule and not the fixture" \
  || bad "gate refuses a bare empty list" "got $(gate_says '{"errors":[]}')"

# 4. `valid` must agree with the exit code, or a caller could trust the field
#    over the code and accept a payload the human form rejected.
je="$(./validate-payload.sh findings fixtures/findings-renamed-property.json \
        --handoff fixtures/handoff-basic.json --json-errors 2>/dev/null)"
if [[ "$(jq -r '.valid' <<<"$je")" == "false" && "$(jq -r '.exit' <<<"$je")" == "3" ]]
then ok "valid:false travels with the non-zero exit it describes"
else bad "valid agrees with the exit code" "got: $je"; fi

# 5. Human output is UNCHANGED without the flag — this adds a channel, it does
#    not replace one. Compared against the pre-EF-079 script in a patched COPY.
mkdir -p "$TMP/pre079"
git -C "$SCRIPT_DIR_REPO" show "$PRE_079_SHA:.eposforge/crosscheck-schemas/validate-payload.sh" \
  > "$TMP/pre079/validate-payload.sh" 2>/dev/null
mkdir -p "$TMP/pre079/lib"
git -C "$SCRIPT_DIR_REPO" show "$PRE_079_SHA:.eposforge/crosscheck-schemas/lib/jsonschema.jq" \
  > "$TMP/pre079/lib/jsonschema.jq" 2>/dev/null
if [[ -s "$TMP/pre079/validate-payload.sh" && -s "$TMP/pre079/lib/jsonschema.jq" ]]; then
  chmod +x "$TMP/pre079/validate-payload.sh"
  for _s in handoff findings disposition; do ln -sf "$PWD/$_s.v1.json" "$TMP/pre079/$_s.v1.json"; done
  ln -sfn "$PWD/fixtures" "$TMP/pre079/fixtures"
  # Control the control: the old copy must actually differ from the new one, or
  # "identical output" would only mean we compared a file with itself.
  if (cd "$TMP/pre079" && ./validate-payload.sh findings fixtures/findings-clean.json --json-errors) >/dev/null 2>&1
  then bad "control: the pre-EF-079 copy rejects --json-errors" "it accepted the flag"
  else ok "control: the pre-EF-079 copy does not know --json-errors"; fi
  diffs=0
  for _f in fixtures/*.json; do
    for _k in handoff findings disposition; do
      _o="$( (cd "$TMP/pre079" && ./validate-payload.sh "$_k" "fixtures/$(basename "$_f")") 2>&1; echo "rc=$?")"
      _n="$( ./validate-payload.sh "$_k" "$_f" 2>&1; echo "rc=$?")"
      [[ "$_o" != "$_n" ]] && diffs=$((diffs+1))
    done
  done
  if (( diffs == 0 ))
  then ok "without the flag, output and exit are identical to pre-EF-079"
  else bad "without the flag, output is identical to pre-EF-079" "$diffs combinations differ"; fi
else
  ok "SKIPPED: pre-EF-079 revision $PRE_079_SHA not reachable in this clone"
fi

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

echo "== an append works from a cold start, because that is the first thing anyone types"
# Every append below is run with `env -u CROSSCHECK_SESSION`: this suite exports
# a session for the earlier blocks, and inheriting it would make SESSION_EXPLICIT
# true and skip the whole pointer path — a test that passes without touching
# what it claims to test.
# "Record claims as you go" is an instruction in a persona file every agent
# reads. Only one CLI has a session-start hook to run `open` first, so on every
# other one the instruction has to survive being followed literally.
CS="$TMP/cold"
mkdir -p "$CS/repo/scripts" "$CS/repo2"
for d in "$CS/repo" "$CS/repo2"; do
  git -C "$d" init -q -b main
  git -C "$d" config user.email crosscheck@example.invalid
  git -C "$d" config user.name crosscheck-test
  echo 'exit 0' > "$d/f.sh"
  git -C "$d" add -A && git -C "$d" commit -qm base
done
# somebody else's session, live, holding the global pointer
CROSSCHECK_DIR="$CS/payloads" CROSSCHECK_SESSION=other-session \
  ./crosscheck-claim open --repo "$CS/repo2" --clearance low >/dev/null 2>&1
printf 'other-session' > "$CS/payloads/current"

out="$(cd "$CS/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" \
       trap 'recorded with no open and no session' 2>&1)"
if grep -q 'opening one for' <<<"$out"; then
  ok "a bare append opens a payload for the repo it is run in"
else
  bad "a bare append opens a payload for the repo it is run in" "$out"
fi
got="$(cd "$CS/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" \
       show --jq '.scope[0].repo_path' 2>/dev/null)"
if [[ "$got" == "$(cd "$CS/repo" && pwd -P)" ]]; then
  ok "and reading it back finds that payload, not the one 'current' names"
else
  bad "and reading it back finds that payload, not the one 'current' names" "got '$got'"
fi
expect_out 0 "the live session's payload was not appended to" \
  jq -r '.traps | length' "$CS/payloads/other-session/round-1/handoff.json"
expect_out other-session "and the global pointer was not stolen" \
  cat "$CS/payloads/current"

echo "== a session that spans two repositories does not split in half"
# `scope` adds a repository to the handoff. If its pointer is not written too,
# a bare append in that second tree finds nothing, misses on `current`, and
# mints a SECOND payload — silently, while `current` belongs to someone else.
( cd "$CS/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" \
    scope --repo "$CS/repo2" --clearance low >/dev/null 2>&1 )
first="$(cd "$CS/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" show --jq '.session' 2>/dev/null)"
( cd "$CS/repo2" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" \
    trap 'appended from the second repo' >/dev/null 2>&1 )
second="$(cd "$CS/repo2" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$CS/payloads" "$OLDPWD/crosscheck-claim" show --jq '.session' 2>/dev/null)"
if [[ -n "$first" && "$first" == "$second" ]]; then
  ok "an append in the second repo lands in the same payload"
else
  bad "an append in the second repo lands in the same payload" "first='$first' second='$second'"
fi
expect_out 0 "and the foreign session is still untouched" \
  jq -r '.traps | length' "$CS/payloads/other-session/round-1/handoff.json"

echo "== upgrading mid-session does not orphan a live payload"
# The pointer filename changed when it was percent-encoded. A miss on the new
# name would mint a second payload — silently, in the middle of somebody's work.
UP="$TMP/upgrade"
mkdir -p "$UP/repo"
git -C "$UP/repo" init -q -b main
git -C "$UP/repo" config user.email crosscheck@example.invalid
git -C "$UP/repo" config user.name crosscheck-test
echo x > "$UP/repo/f"; git -C "$UP/repo" add -A && git -C "$UP/repo" commit -qm base
CROSSCHECK_DIR="$UP/p" CROSSCHECK_SESSION=upgraded \
  ./crosscheck-claim open --repo "$UP/repo" --clearance low >/dev/null 2>&1
legacy="$(printf '%s' "$(cd "$UP/repo" && pwd -P)" | sed 's|^/||; s|/|_|g')"
mv "$UP/p/by-repo/"* "$UP/p/by-repo/$legacy"
printf 'somebody-else' > "$UP/p/current"
( cd "$UP/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$UP/p" "$OLDPWD/crosscheck-claim" trap 'after the upgrade' ) >/dev/null 2>&1
got="$(cd "$UP/repo" && env -u CROSSCHECK_SESSION CROSSCHECK_DIR="$UP/p" "$OLDPWD/crosscheck-claim" show --jq '.session' 2>/dev/null)"
if [[ "$got" == "upgraded" ]]; then
  ok "a pointer written under the old name still finds its payload"
else
  bad "a pointer written under the old name still finds its payload" "got '$got'"
fi

echo "== two repositories cannot share one pointer filename"
# /a/b/c and /a/b_c both became a_b_c when "/" was replaced by "_", so a bare
# append could bind to a different tree with no error.
mkdir -p "$CS/enc/x/y" "$CS/enc/x_y"
p1="$(CROSSCHECK_DIR="$CS/payloads" bash -c 'ROOT="'"$CS/payloads"'"; source /dev/stdin <<<"$(sed -n "/^repo_pointer()/,/^}/p" ./crosscheck-claim)"; repo_pointer "'"$CS/enc/x/y"'"')"
p2="$(CROSSCHECK_DIR="$CS/payloads" bash -c 'ROOT="'"$CS/payloads"'"; source /dev/stdin <<<"$(sed -n "/^repo_pointer()/,/^}/p" ./crosscheck-claim)"; repo_pointer "'"$CS/enc/x_y"'"')"
if [[ -n "$p1" && "$p1" != "$p2" ]]; then
  ok "x/y and x_y get different pointer files"
else
  bad "x/y and x_y get different pointer files" "both '$p1'"
fi

echo "== a payload opened before the work started does not report a vacuous coverage zero"
# The session-start trigger opens the handoff when the tree is still clean, so
# `dirty` is stamped false. Left alone, coverage compares base..head over an
# empty range and says uncovered=0 for a change it never looked at.
VS="$TMP/vs-repo"
mkdir -p "$VS"
git -C "$VS" init -q -b main
git -C "$VS" config user.email crosscheck@example.invalid
git -C "$VS" config user.name  crosscheck-test
echo base > "$VS/tracked.md"
git -C "$VS" add -A && git -C "$VS" commit -qm base
VSHA="$(git -C "$VS" rev-parse HEAD)"
jq -n --arg r "$VS" --arg h "$VSHA" \
  '{schema:"eposforge.crosscheck.handoff/1",round:1,session:"vs",
    implementer:{agent:"alpha",provider:"p",model:"m"},
    scope:[{repo_path:$r,policy_key:"vs",clearance:"low",base_sha:$h,head_sha:$h,dirty:false}],
    clearance_required:"low",claims:[],traps:[],attack_first:[],out_of_scope:[],
    ground_rules:[],budget:{est_tokens:1,rendered_bytes:4,cap:8000,over_budget:false}}' \
  > "$TMP/vs.json"
echo "work happened after the payload was opened" >> "$VS/tracked.md"
./crosscheck-verify-scope.sh --handoff "$TMP/vs.json" --write --quiet >/dev/null 2>&1
expect_out true "verify-scope re-reads dirty rather than believing the payload" \
  jq -r '.scope[0].dirty' "$TMP/vs.json"
out="$(./crosscheck-coverage.sh --handoff "$TMP/vs.json" 2>&1)"
if grep -q 'tracked.md' <<<"$out"; then
  ok "coverage then sees the working tree it would otherwise have missed"
else
  bad "coverage then sees the working tree it would otherwise have missed" "$out"
fi

echo "== a finding may name a claim without crashing the validator"
# The claim_ref check used to read `.claim_ref` with the claims array as input,
# so jq aborted and a well-formed payload read INVALID for a reason that had
# nothing to do with it. Both directions are tested, because the crash made the
# real check unreachable as well.
jq '.findings[0].claim_ref = "c1"' fixtures/findings-clean.json > "$TMP/ref-ok.json"
expect_exit 0 "a finding pointing at a declared claim validates" \
  ./validate-payload.sh findings "$TMP/ref-ok.json" --handoff fixtures/handoff-basic.json
jq '.findings[0].claim_ref = "c99"' fixtures/findings-clean.json > "$TMP/ref-bad.json"
out="$(./validate-payload.sh findings "$TMP/ref-bad.json" --handoff fixtures/handoff-basic.json 2>&1)"; rc=$?
if [[ $rc -eq 1 ]] && grep -q 'references unknown claim c99' <<<"$out"; then
  ok "a finding pointing at a claim that does not exist is named"
else
  bad "a finding pointing at a claim that does not exist is named" "rc=$rc $out"
fi

echo "== --files alone does not freeze today's directory into the claim"
./crosscheck-claim add --statement "the linter is still there" --evidence-cmd 'test -f scripts/lint.sh' \
  --check exit0 --files scripts/lint.sh >/dev/null 2>&1
if [[ "$(jq -r '.claims[-1] | has("cwd")' "$H")" == "false" ]]; then
  ok "a claim resolved from files[] records no cwd"
else
  bad "a claim resolved from files[] records no cwd" "$(jq -c '.claims[-1]' "$H")"
fi
./crosscheck-claim add --statement "explicitly here" --evidence-cmd 'true' \
  --check exit0 --cwd "$R" --files scripts/lint.sh >/dev/null 2>&1
if [[ "$(jq -r '.claims[-1].cwd' "$H")" == "$R" ]]; then
  ok "an explicit --cwd is recorded as the author wrote it"
else
  bad "an explicit --cwd is recorded as the author wrote it" "$(jq -c '.claims[-1]' "$H")"
fi
./crosscheck-run-checks.sh --handoff "$H" >/dev/null 2>&1
if [[ "$(jq -r '[.check_results[] | select(.ran and .matched)] | length' "$H")" -ge 3 ]]; then
  ok "both claims still run in the right repository without a stored cwd"
else
  bad "both claims still run in the right repository without a stored cwd" "$(jq -c '.check_results' "$H")"
fi

echo "== a live session is not stolen just because its payload moved to round 2"
LIVE="$TMP/live-payloads"
CROSSCHECK_DIR="$LIVE" CROSSCHECK_SESSION=session-a CROSSCHECK_ROUND=2 \
  ./crosscheck-claim open --repo "$R" --clearance low >/dev/null 2>&1
# The round-2 payload is the case that used to be invisible: the liveness check
# only looked at round-$CROSSCHECK_ROUND, so `current` was repointed at exactly
# the moment the other session was most active.
CROSSCHECK_DIR="$LIVE" CROSSCHECK_ROUND=1 \
  expect_exit 0 "a session that names itself may open alongside a live one" \
  ./crosscheck-claim open --repo "$R" --clearance low --session session-b
if [[ "$(cat "$LIVE/current" 2>/dev/null)" == "session-a" ]]; then
  ok "current still points at the live session"
else
  bad "current still points at the live session" "$(cat "$LIVE/current" 2>/dev/null)"
fi
if [[ -r "$LIVE/session-b/round-1/handoff.json" ]]; then
  ok "and the new session still got its own payload"
else
  bad "and the new session still got its own payload" "no handoff written"
fi

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

echo "== a session that commits its work does not hand over an empty commit range"
# The failure this catches is silent by construction: head_sha is stamped when
# the handoff opens, the session then commits, and base..head is empty. Nothing
# drifted, so no integrity check fires — coverage just reports 0 uncovered for a
# change it never looked at.
RC1="$TMP/repo-commit"
mkdir -p "$RC1"
git -C "$RC1" init -q -b main
git -C "$RC1" config user.email crosscheck@example.invalid
git -C "$RC1" config user.name  crosscheck-test
printf 'one\n' > "$RC1/a.txt"
git -C "$RC1" add -A && git -C "$RC1" commit -qm base
( export CROSSCHECK_DIR="$TMP/pay-commit" CROSSCHECK_SESSION="commit-session"
  ./crosscheck-claim open --repo "$RC1" --policy-key example_app --clearance medium >/dev/null 2>&1
  printf 'two\n' > "$RC1/b.txt"
  git -C "$RC1" add -A && git -C "$RC1" commit -qm work )
HC="$TMP/pay-commit/commit-session/round-1/handoff.json"
if [[ "$(jq -r '.scope[0].base_sha == .scope[0].head_sha' "$HC")" == "true" ]]; then
  ok "the payload really does freeze head_sha at open time"
else
  bad "head_sha frozen at open" "base and head already differ, so this test proves nothing"
fi
expect_exit 0 "refresh advances head_sha" \
  env CROSSCHECK_DIR="$TMP/pay-commit" CROSSCHECK_SESSION="commit-session" \
      bash -c "cd '$RC1' && '$PWD/crosscheck-claim' refresh"
expect_out "$(git -C "$RC1" rev-parse HEAD)" "head_sha is now the commit the work ended on" \
  jq -r '.scope[0].head_sha' "$HC"
expect_out "$(git -C "$RC1" rev-parse HEAD~1)" "and base_sha was NOT moved with it" \
  jq -r '.scope[0].base_sha' "$HC"
n="$(CROSSCHECK_DIR="$TMP/pay-commit" ./crosscheck-coverage.sh --handoff "$HC" 2>&1 | grep -c 'b.txt')"
[[ "$n" == "1" ]] && ok "coverage now sees the committed file it could not see before" \
  || bad "coverage sees the committed file" "b.txt not named in the uncovered set"
expect_exit 2 "refresh does not invent a payload for a session that has none" \
  env CROSSCHECK_DIR="$TMP/pay-none" CROSSCHECK_SESSION="nothing-here" \
      bash -c "cd '$RC1' && '$PWD/crosscheck-claim' refresh"

echo "== the next round is a delta, and only opens when the last one was answered"
NRD="$TMP/nr"
mk_round1() {  # mk_round1 <dir> <findings-fixture>
  mkdir -p "$1/round-1"
  jq --arg r "$R" --arg b "$BASE" --arg h "$HEAD_SHA" '
     .scope = [{repo_path:$r, policy_key:"example_app", clearance:"medium",
                base_sha:$b, head_sha:$h, dirty:false, integrity:"ok",
                verified_at:"2026-01-01T00:00:00Z"}]' \
     fixtures/handoff-basic.json > "$1/round-1/handoff.json"
  jq --arg h "$1/round-1/handoff.json" '.handoff_ref=$h' "$2" > "$1/round-1/findings.json"
  jq --arg f "$1/round-1/findings.json" '.findings_ref=$f' \
     fixtures/disposition-clean.json > "$1/round-1/disposition.json"
}

mk_round1 "$NRD/go" fixtures/findings-claim-refuted.json
expect_exit 0 "a disposed round opens the next one" \
  ./crosscheck-next-round.sh --handoff "$NRD/go/round-1/handoff.json"
N2="$NRD/go/round-2/handoff.json"
expect_exit 0 "the round it wrote validates"      ./validate-payload.sh handoff "$N2"
expect_out "$HEAD_SHA" "round 2 starts where round 1 ended" \
  jq -r '.scope[0].base_sha' "$N2"
expect_out "0 0 0" "claims, traps and attacks do not carry over" \
  jq -r '"\(.claims|length) \(.traps|length) \(.attack_first|length)"' "$N2"
expect_out "$NRD/go/round-1/disposition.json" "it points at the answers it was opened on" \
  jq -r '.disposition_ref' "$N2"
# The delta is supposed to be visible as a number, not as an intention: a loop
# whose round 3 is bigger than its round 1 has gone quadratic and nobody noticed.
b1="$(wc -c <"$NRD/go/round-1/handoff.json")"; b2="$(wc -c <"$N2")"
if (( b2 < b1 )); then ok "the next round starts smaller than the one it answers ($b2 < $b1 bytes)"
else bad "the next round starts smaller" "round 2 is $b2 bytes against round 1's $b1"; fi
expect_exit 1 "a round that already exists is not overwritten" \
  ./crosscheck-next-round.sh --handoff "$NRD/go/round-1/handoff.json"

mk_round1 "$NRD/undisposed" fixtures/findings-claim-refuted.json
rm -f "$NRD/undisposed/round-1/disposition.json"
expect_exit 1 "findings that were never answered do not open a round" \
  ./crosscheck-next-round.sh --handoff "$NRD/undisposed/round-1/handoff.json"

# The failure this one catches is the quiet kind: a disposition file exists, is
# well-formed, and skips a finding. Presence would have been enough to pass.
mk_round1 "$NRD/partial" fixtures/findings-claim-refuted.json
jq '.dispositions = []' "$NRD/partial/round-1/disposition.json" > "$TMP/part.json"
mv "$TMP/part.json" "$NRD/partial/round-1/disposition.json"
expect_exit 1 "a disposition that skips a finding does not open a round" \
  ./crosscheck-next-round.sh --handoff "$NRD/partial/round-1/handoff.json"

mk_round1 "$NRD/done" fixtures/findings-clean.json
expect_exit 1 "a loop the stop rule ended does not open another round" \
  ./crosscheck-next-round.sh --handoff "$NRD/done/round-1/handoff.json"
expect_exit 0 "--force opens it anyway, and says so" \
  ./crosscheck-next-round.sh --handoff "$NRD/done/round-1/handoff.json" --force

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
