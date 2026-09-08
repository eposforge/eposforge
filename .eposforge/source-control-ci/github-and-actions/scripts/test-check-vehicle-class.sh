#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# test-check-vehicle-class.sh — no LLM, no network. Exercises gate G1 against
# throwaway git trees. Fixtures mirror EF-090's plan (backlog/plans/EF-090-*):
#   fail: a new scripts/do_it.py with no vehicle-class
#   pass: the same file with `# vehicle-class: in-repo-pipeline`
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-vehicle-class.sh"
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
  if [[ "$rc" == "$want" ]]; then ok "$label"; else bad "$label" "expected $want got $rc: $(echo "$out" | tail -3)"; fi
}

mk_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email "vc-test@example.test"
  git -C "$d" config user.name "vc-test"
  git -C "$d" config commit.gpgsign false
  git -C "$d" checkout -q -b main
}

echo "== G1: new file in a declared code root, no marker => fail (staged)"
REPO="$TMP/repo1"
mk_repo "$REPO"
git -C "$REPO" commit -q --allow-empty -m "root"
mkdir -p "$REPO/.eposforge/some-component/scripts"
printf 'print("hi")\n' > "$REPO/.eposforge/some-component/scripts/do_it.py"
git -C "$REPO" -C "$REPO" add -A 2>/dev/null || git -C "$REPO" add -A
expect_exit 1 "no marker, staged => fail" \
  bash -c "cd '$REPO' && '$CHECK' --staged"

echo "== G1: same file, valid marker => pass (staged)"
{
  printf '# vehicle-class: in-repo-pipeline\n'
  cat "$REPO/.eposforge/some-component/scripts/do_it.py"
} > "$REPO/.eposforge/some-component/scripts/do_it.py.new"
mv "$REPO/.eposforge/some-component/scripts/do_it.py.new" "$REPO/.eposforge/some-component/scripts/do_it.py"
git -C "$REPO" add -A
expect_exit 0 "valid marker, staged => pass" \
  bash -c "cd '$REPO' && '$CHECK' --staged"
git -C "$REPO" commit -q -m "add do_it.py with vehicle-class"

echo "== G1: invalid class value => fail"
REPO2="$TMP/repo2"
mk_repo "$REPO2"
git -C "$REPO2" commit -q --allow-empty -m "root"
mkdir -p "$REPO2/skills/some-skill/scripts"
printf '#!/usr/bin/env bash\n# vehicle-class: not-a-real-class\necho hi\n' > "$REPO2/skills/some-skill/scripts/run.sh"
git -C "$REPO2" add -A
expect_exit 1 "invalid class value => fail" \
  bash -c "cd '$REPO2' && '$CHECK' --staged"

echo "== G1: skills/*/scripts/* path is a declared code root"
REPO3="$TMP/repo3"
mk_repo "$REPO3"
git -C "$REPO3" commit -q --allow-empty -m "root"
mkdir -p "$REPO3/skills/other-skill/scripts"
printf '#!/usr/bin/env bash\n# vehicle-class: host-ci-glue\necho hi\n' > "$REPO3/skills/other-skill/scripts/launch.sh"
git -C "$REPO3" add -A
expect_exit 0 "skills/*/scripts/* with a valid marker => pass" \
  bash -c "cd '$REPO3' && '$CHECK' --staged"

echo "== G1: a file outside any declared code root is never scanned"
REPO4="$TMP/repo4"
mk_repo "$REPO4"
git -C "$REPO4" commit -q --allow-empty -m "root"
mkdir -p "$REPO4/docs"
printf 'no marker here\n' > "$REPO4/docs/notes.md"
git -C "$REPO4" add -A
expect_exit 0 "file outside a declared code root => pass regardless" \
  bash -c "cd '$REPO4' && '$CHECK' --staged"

echo "== G1: only ADDED files are scanned, not merely touched"
REPO5="$TMP/repo5"
mk_repo "$REPO5"
mkdir -p "$REPO5/.eposforge/comp/scripts"
printf '# vehicle-class: in-repo-pipeline\necho v1\n' > "$REPO5/.eposforge/comp/scripts/existing.sh"
git -C "$REPO5" add -A
git -C "$REPO5" commit -q -m "existing, already classified"
BASE5="$(git -C "$REPO5" rev-parse HEAD)"
# Now strip the marker on an already-committed file and touch (not add) it.
printf 'echo v2 no marker anymore\n' > "$REPO5/.eposforge/comp/scripts/existing.sh"
git -C "$REPO5" add -A
git -C "$REPO5" commit -q -m "touch existing file, marker now missing"
expect_exit 0 "--changed-against: touched-not-added file is out of G1's v1 scan set" \
  bash -c "cd '$REPO5' && '$CHECK' --changed-against '$BASE5'"

echo "== G1: a '//'-comment marker is recognized (comment-prefix agnostic, Standard 15 names no language)"
REPO7="$TMP/repo7"
mk_repo "$REPO7"
git -C "$REPO7" commit -q --allow-empty -m "root"
mkdir -p "$REPO7/.eposforge/comp3/scripts"
printf '// vehicle-class: library-or-service\nconsole.log("hi");\n' > "$REPO7/.eposforge/comp3/scripts/run.js"
git -C "$REPO7" add -A
expect_exit 0 "//-style marker => pass" \
  bash -c "cd '$REPO7' && '$CHECK' --staged"

echo "== G1: --changed-against catches a newly added file missing its marker"
REPO6="$TMP/repo6"
mk_repo "$REPO6"
git -C "$REPO6" commit -q --allow-empty -m "root"
BASE6="$(git -C "$REPO6" rev-parse HEAD)"
mkdir -p "$REPO6/.eposforge/comp2/scripts"
printf 'echo new, no marker\n' > "$REPO6/.eposforge/comp2/scripts/new.sh"
git -C "$REPO6" add -A
git -C "$REPO6" commit -q -m "add new.sh"
expect_exit 1 "--changed-against: newly added file with no marker => fail" \
  bash -c "cd '$REPO6' && '$CHECK' --changed-against '$BASE6'"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
