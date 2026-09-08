#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# test-check-operating-inference.sh — no LLM, no network. Exercises gate G4
# against throwaway git trees. Fixtures mirror EF-090's plan
# (backlog/plans/EF-090-*):
#   fail: a spec with no operating_inference
#   fail: operating_inference: continuous-loop with no reason or budget
#   pass: operating_inference: none
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-operating-inference.sh"
PASS=0
FAIL=0
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }

expect_exit() {
  local want="$1" label="$2"; shift 2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" == "$want" ]]; then ok "$label"; else bad "$label" "expected $want got $rc: $(echo "$out" | tail -8)"; fi
}

mk_repo() {
  local d="$1"
  mkdir -p "$d/.eposforge/backlog/file-based-backlog"
  git -C "$d" init -q
  git -C "$d" config user.email "oi-test@example.test"
  git -C "$d" config user.name "oi-test"
  git -C "$d" config commit.gpgsign false
  git -C "$d" checkout -q -b main
}

echo "== G4: allowlisted file with no operating_inference field => fail"
REPO="$TMP/repo1"
mk_repo "$REPO"
printf -- '# SPEC.md\n\nno such field here\n' > "$REPO/.eposforge/SPEC.md"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "spec, no field"
expect_exit 1 "missing field => fail" \
  bash -c "cd '$REPO' && '$CHECK'"

echo "== G4: operating_inference: none => pass"
REPO2="$TMP/repo2"
mk_repo "$REPO2"
printf -- '# SPEC.md\n\n| `operating_inference` | `none` — deterministic |\n' > "$REPO2/.eposforge/SPEC.md"
git -C "$REPO2" add -A
git -C "$REPO2" commit -q -m "spec, none"
expect_exit 0 "operating_inference: none => pass" \
  bash -c "cd '$REPO2' && '$CHECK'"

echo "== G4: operating_inference: on-demand-judgment => pass"
REPO3="$TMP/repo3"
mk_repo "$REPO3"
printf -- '| `operating_inference` | `on-demand-judgment` — a program holds the path |\n' > "$REPO3/.eposforge/backlog/file-based-backlog/file-based-backlog.md"
git -C "$REPO3" add -A
git -C "$REPO3" commit -q -m "backlog contract, on-demand-judgment"
expect_exit 0 "operating_inference: on-demand-judgment => pass" \
  bash -c "cd '$REPO3' && '$CHECK'"

echo "== G4: continuous-loop with no reason or budget => fail"
REPO4="$TMP/repo4"
mk_repo "$REPO4"
printf -- '| `operating_inference` | `continuous-loop` — an agent stays in the loop |\n' > "$REPO4/.eposforge/SPEC.md"
git -C "$REPO4" add -A
git -C "$REPO4" commit -q -m "spec, continuous-loop, no reason/budget"
expect_exit 1 "continuous-loop with no reason/budget => fail" \
  bash -c "cd '$REPO4' && '$CHECK'"

echo "== G4: continuous-loop WITH reason and budget => pass"
REPO5="$TMP/repo5"
mk_repo "$REPO5"
cat > "$REPO5/.eposforge/SPEC.md" <<'EOF'
| `operating_inference` | `continuous-loop` — an agent stays in the loop |
| `operating_inference_reason` | a program cannot hold this path because X |
| `operating_inference_budget` | .eposforge/inference/budget-policy.json |
EOF
git -C "$REPO5" add -A
git -C "$REPO5" commit -q -m "spec, continuous-loop, with reason/budget"
expect_exit 0 "continuous-loop with reason+budget => pass" \
  bash -c "cd '$REPO5' && '$CHECK'"

echo "== G4: invalid enum value => fail"
REPO6="$TMP/repo6"
mk_repo "$REPO6"
printf -- '| `operating_inference` | `sometimes` — not a real value |\n' > "$REPO6/.eposforge/SPEC.md"
git -C "$REPO6" add -A
git -C "$REPO6" commit -q -m "spec, invalid value"
expect_exit 1 "invalid enum value => fail" \
  bash -c "cd '$REPO6' && '$CHECK'"

echo "== G4: a value cell containing a stray pipe does not silently truncate to a valid-looking prefix"
REPO8="$TMP/repo8"
mk_repo "$REPO8"
printf -- '| `operating_inference` | `none|foo` — malformed, pipe leaked into the cell |\n' > "$REPO8/.eposforge/SPEC.md"
git -C "$REPO8" add -A
git -C "$REPO8" commit -q -m "spec, value with a stray pipe"
expect_exit 1 "stray pipe in value cell => fail loud, not silently 'none'" \
  bash -c "cd '$REPO8' && '$CHECK'"

echo "== G4: a malformed value cell followed by a coincidental valid-looking backtick token still fails loud"
REPO9="$TMP/repo9"
mk_repo "$REPO9"
printf -- '| `operating_inference` | `none|foo` - `none` |\n' > "$REPO9/.eposforge/SPEC.md"
git -C "$REPO9" add -A
git -C "$REPO9" commit -q -m "spec, malformed cell with a trailing decoy token"
expect_exit 1 "decoy backtick token later on the line does not rescue a malformed cell" \
  bash -c "cd '$REPO9' && '$CHECK'"

echo "== G4: --staged reads the git index, not the working tree"
REPO10="$TMP/repo10"
mk_repo "$REPO10"
printf -- '| `operating_inference` | `none` — deterministic |\n' > "$REPO10/.eposforge/SPEC.md"
git -C "$REPO10" add -A
git -C "$REPO10" commit -q -m "spec, valid, committed"
# Working tree now has a broken value, but nothing is staged for it.
printf -- '| `operating_inference` | `garbage` — broken on disk only |\n' > "$REPO10/.eposforge/SPEC.md"
expect_exit 0 "--staged ignores an unstaged working-tree break (checks the index, which still matches HEAD)" \
  bash -c "cd '$REPO10' && '$CHECK' --staged"
expect_exit 1 "no --staged (default) reads the working tree and sees the break" \
  bash -c "cd '$REPO10' && '$CHECK'"
# Now actually stage the break: --staged must catch it.
git -C "$REPO10" add -A
expect_exit 1 "--staged catches a value that IS staged" \
  bash -c "cd '$REPO10' && '$CHECK' --staged"

echo "== G4: a file outside the two-file allowlist is never checked"
REPO7="$TMP/repo7"
mk_repo "$REPO7"
printf -- '# SPEC.md\n\n| `operating_inference` | `none` — deterministic |\n' > "$REPO7/.eposforge/SPEC.md"
mkdir -p "$REPO7/01-architecture/02-components"
printf -- 'Living Spec discussion with no operating_inference field at all.\n' > "$REPO7/01-architecture/02-components/living-spec.md"
git -C "$REPO7" add -A
git -C "$REPO7" commit -q -m "unrelated doc using the phrase Living Spec"
expect_exit 0 "non-allowlisted file with no field => still pass (scope discipline)" \
  bash -c "cd '$REPO7' && '$CHECK'"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
