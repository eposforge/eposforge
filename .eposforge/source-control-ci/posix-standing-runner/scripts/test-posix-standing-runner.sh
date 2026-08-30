#!/usr/bin/env bash
# test-posix-standing-runner.sh — no LLM, no network. Exercises the dispatcher
# against throwaway git trees so the contract properties are checkable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$SCRIPT_DIR/run-standing.sh"
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
  if [[ "$rc" == "$want" ]]; then ok "$label"; else bad "$label" "expected $want got $rc: $(echo "$out" | head -1)"; fi
}

mk_repo() {
  local d="$1"
  mkdir -p "$d/.eposforge/source-control-ci/posix-standing-runner/scripts"
  mkdir -p "$d/scripts"
  git -C "$d" init -q
  git -C "$d" config user.email "runner-test@example.test"
  git -C "$d" config user.name "runner-test"
  git -C "$d" config commit.gpgsign false
  git -C "$d" checkout -q -b main
}

write_exec() {
  local path="$1" body="$2"
  printf '%s\n' "$body" > "$path"
  chmod +x "$path"
}

echo "== one command, three repo classes"

AGENT="$TMP/agent-config"
PLAT="$TMP/platform"
PROD="$TMP/product"
mk_repo "$AGENT"
mk_repo "$PLAT"
mk_repo "$PROD"

write_exec "$AGENT/.eposforge/standing-suite" $'#!/usr/bin/env bash\nset -euo pipefail\necho agent-config-ok\n'
write_exec "$PLAT/.eposforge/standing-suite" $'#!/usr/bin/env bash\nset -euo pipefail\necho platform-ok\n'
write_exec "$PROD/.eposforge/standing-suite" $'#!/usr/bin/env bash\nset -euo pipefail\necho product-ok\n'
# The dispatcher itself is not required inside a product tree; standing-suite is.
git -C "$AGENT" add -A && git -C "$AGENT" commit -qm "suite"
git -C "$PLAT" add -A && git -C "$PLAT" commit -qm "suite"
git -C "$PROD" add -A && git -C "$PROD" commit -qm "suite"

OUT="$("$RUN" "$AGENT" "$PLAT" "$PROD" 2>&1)" || { bad "three-class invocation" "$OUT"; OUT=""; }
echo "$OUT" | grep -q agent-config-ok && echo "$OUT" | grep -q platform-ok && echo "$OUT" | grep -q product-ok \
  && ok "one invocation covers agent-config + platform + product" \
  || bad "one invocation covers three classes" "$OUT"

echo "== same command from a second clone (no host payload path, no first-clone path)"

CLONE="$TMP/product-clone"
git clone -q "$PROD" "$CLONE"
# Run from inside the clone using only repo-relative paths.
OUT="$(cd "$CLONE" && "$RUN" 2>&1)" || { bad "clone-local run" "$OUT"; OUT=""; }
echo "$OUT" | grep -q product-ok && ok "same dispatcher works from a second clone" \
  || bad "clone-local run" "$OUT"
# And the suite itself is the clone-local command.
OUT="$(cd "$CLONE" && ./.eposforge/standing-suite 2>&1)" || { bad "suite from clone" "$OUT"; OUT=""; }
echo "$OUT" | grep -q product-ok && ok "standing-suite itself runs from a second clone" \
  || bad "suite from clone" "$OUT"

echo "== --accepts is repo-local scripts only"

expect_exit 0 "accepts the suite path" \
  "$RUN" --accepts "./.eposforge/standing-suite" --repo "$PROD"
expect_exit 1 "refuses an absolute host path" \
  "$RUN" --accepts "/tmp/not-in-repo.sh" --repo "$PROD"
expect_exit 1 "refuses parent-directory escape" \
  "$RUN" --accepts "../outside.sh" --repo "$PROD"
expect_exit 1 "refuses a PATH binary that is not in the tree" \
  "$RUN" --accepts "pytest" --repo "$PROD"

LIST="$TMP/listed"
mk_repo "$LIST"
write_exec "$LIST/scripts/check.sh" $'#!/usr/bin/env bash\necho listed-ok\n'
printf '%s\n' "scripts/check.sh" > "$LIST/.eposforge/standing-suite"
git -C "$LIST" add -A && git -C "$LIST" commit -qm "listed"
expect_exit 0 "accepts a listed repo-local script" \
  "$RUN" --accepts "scripts/check.sh" --repo "$LIST"
expect_exit 0 "listed suite itself still accepted" \
  "$RUN" --accepts ".eposforge/standing-suite" --repo "$LIST"
write_exec "$LIST/scripts/other.sh" $'#!/usr/bin/env bash\necho no\n'
expect_exit 1 "refuses a repo script that is not in the suite" \
  "$RUN" --accepts "scripts/other.sh" --repo "$LIST"
chmod -x "$LIST/scripts/check.sh"
expect_exit 1 "refuses a listed script that is not executable" \
  "$RUN" --accepts "scripts/check.sh" --repo "$LIST"
chmod +x "$LIST/scripts/check.sh"
OUT="$("$RUN" "$LIST" 2>&1)" || { bad "run listed suite" "$OUT"; OUT=""; }
echo "$OUT" | grep -q listed-ok && ok "list-form suite runs the listed command" \
  || bad "list-form suite" "$OUT"

echo "== held-out assertions"

HELD="$TMP/held-out"
mkdir -p "$HELD"
write_exec "$HELD/hidden.sh" $'#!/usr/bin/env bash\necho held-out-ok\n'
OUT="$("$RUN" --held-out "$HELD" "$PROD" 2>&1)" || { bad "held-out run" "$OUT"; OUT=""; }
echo "$OUT" | grep -q held-out-ok && echo "$OUT" | grep -q product-ok \
  && ok "held-out checks run in addition to the suite" \
  || bad "held-out run" "$OUT"

echo "== gate not edited in the same change"

# Introduction: gate files not on base, other files present — allowed.
INTRO="$TMP/intro"
mk_repo "$INTRO"
echo "code" > "$INTRO/app.txt"
git -C "$INTRO" add -A && git -C "$INTRO" commit -qm "code first"
# Record that commit as origin/main analogue via --base.
BASE_INTRO="$(git -C "$INTRO" rev-parse HEAD)"
write_exec "$INTRO/.eposforge/standing-suite" $'#!/usr/bin/env bash\necho intro-ok\n'
echo "more" >> "$INTRO/app.txt"
git -C "$INTRO" add -A && git -C "$INTRO" commit -qm "introduce gate with code"
expect_exit 0 "introducing the gate with other files is allowed" \
  "$RUN" --check-gate --repo "$INTRO" --base "$BASE_INTRO"

# After the gate exists, mixing gate edits with scored files fails.
EXIST="$TMP/existed"
mk_repo "$EXIST"
write_exec "$EXIST/.eposforge/standing-suite" $'#!/usr/bin/env bash\necho existed-ok\n'
echo "code" > "$EXIST/app.txt"
git -C "$EXIST" add -A && git -C "$EXIST" commit -qm "gate already there"
BASE_EX="$(git -C "$EXIST" rev-parse HEAD)"
echo "changed" >> "$EXIST/.eposforge/standing-suite"
echo "changed" >> "$EXIST/app.txt"
git -C "$EXIST" add -A && git -C "$EXIST" commit -qm "mixed"
expect_exit 1 "mixing a gate edit with scored files is refused" \
  "$RUN" --check-gate --repo "$EXIST" --base "$BASE_EX"

# Net range is what a PR sees. Reset and make a gate-only commit.
git -C "$EXIST" reset --hard -q "$BASE_EX"
echo "# comment" >> "$EXIST/.eposforge/standing-suite"
git -C "$EXIST" add -A && git -C "$EXIST" commit -qm "gate only"
expect_exit 0 "a gate-only change is allowed" \
  "$RUN" --check-gate --repo "$EXIST" --base "$BASE_EX"

git -C "$EXIST" reset --hard -q "$BASE_EX"
echo "only code" >> "$EXIST/app.txt"
git -C "$EXIST" add -A && git -C "$EXIST" commit -qm "code only"
expect_exit 0 "a scored-files-only change is allowed" \
  "$RUN" --check-gate --repo "$EXIST" --base "$BASE_EX"

echo "== nested fixture inside a parent git tree does not re-enter the parent suite"
PARENT="$TMP/parent-git"
mk_repo "$PARENT"
write_exec "$PARENT/.eposforge/standing-suite" $'#!/usr/bin/env bash\necho PARENT-SUITE-MUST-NOT-RUN; exit 1\n'
NEST="$PARENT/fixtures/product"
mkdir -p "$NEST/.eposforge"
write_exec "$NEST/.eposforge/standing-suite" $'#!/usr/bin/env bash\necho nested-ok\n'
git -C "$PARENT" add -A && git -C "$PARENT" commit -qm "nested fixture"
OUT="$("$RUN" "$NEST" 2>&1)" || { bad "nested fixture run" "$OUT"; OUT=""; }
echo "$OUT" | grep -q nested-ok && echo "$OUT" | grep -qv PARENT-SUITE \
  && ok "nested standing-suite is used, parent git root is not" \
  || bad "nested fixture" "$OUT"

echo "== missing suite fails closed"
EMPTY="$TMP/empty"
mk_repo "$EMPTY"
git -C "$EMPTY" add -A && git -C "$EMPTY" commit -qm "no suite" --allow-empty
expect_exit 1 "a tree with no standing-suite is refused" \
  "$RUN" "$EMPTY"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
