#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# test-check-procedure-skills.sh — no LLM, no network. Exercises gates G2/G3
# against throwaway git trees. Fixtures mirror EF-090's plan
# (backlog/plans/EF-090-*):
#   G3 fail: `bash .eposforge/foo.sh`
#   G3 pass: `bash "${EPOSFORGE_HOME:?}/.eposforge/foo.sh"`
#   G2 fail (advisory): a SKILL.md with ten bash steps and no program pointer
#   G2 pass: a SKILL.md that states when/dry-run/gate and calls the program
#            via a home variable
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-procedure-skills.sh"
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
  if [[ "$rc" == "$want" ]]; then ok "$label"; else bad "$label" "expected $want got $rc: $(echo "$out" | tail -5)"; fi
}

expect_stderr_contains() {
  local pattern="$1" label="$2"; shift 2
  local out
  out="$("$@" 2>&1)" || true
  if grep -q -- "$pattern" <<<"$out"; then ok "$label"; else bad "$label" "did not find '$pattern' in: $(echo "$out" | tail -8)"; fi
}

mk_repo() {
  local d="$1"
  mkdir -p "$d/skills"
  git -C "$d" init -q
  git -C "$d" config user.email "ps-test@example.test"
  git -C "$d" config user.name "ps-test"
  git -C "$d" config commit.gpgsign false
  git -C "$d" checkout -q -b main
}

echo "== G3: cwd-relative invocation in SKILL.md => reported, warn stage stays exit 0"
REPO="$TMP/repo1"
mk_repo "$REPO"
git -C "$REPO" commit -q --allow-empty -m "root"
mkdir -p "$REPO/skills/foo-skill"
cat > "$REPO/skills/foo-skill/SKILL.md" <<'EOF'
---
name: foo-skill
description: does foo
---
Run it:

```bash
bash .eposforge/foo/scripts/foo.sh
```
EOF
git -C "$REPO" add -A
expect_exit 0 "warn stage: G3 hit reported but does not fail" \
  bash -c "cd '$REPO' && '$CHECK' --staged"
expect_stderr_contains "G3" "warn stage: G3 section present in output" \
  bash -c "cd '$REPO' && '$CHECK' --staged"

echo "== G3: home-variable invocation => no G3 finding"
cat > "$REPO/skills/foo-skill/SKILL.md" <<'EOF'
---
name: foo-skill
description: does foo
---
When: needed. Dry-run: `--dry-run`. Gate: none.

Run it:

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/foo/scripts/foo.sh"
```

Verify: exit code 0.
EOF
git -C "$REPO" add -A
OUT="$(cd "$REPO" && "$CHECK" --staged 2>&1)"
if ! grep -q "G3 —" <<<"$OUT"; then ok "home-variable invocation has no G3 finding"; else bad "home-variable invocation has no G3 finding" "$OUT"; fi
git -C "$REPO" commit -q -m "fixed skill"

echo "== G2 (advisory): ten bash steps, no home-variable invocation => reported"
REPO2="$TMP/repo2"
mk_repo "$REPO2"
git -C "$REPO2" commit -q --allow-empty -m "root"
mkdir -p "$REPO2/skills/recipe-skill"
{
  echo "---"
  echo "name: recipe-skill"
  echo "description: a step-list recipe"
  echo "---"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    echo ""
    echo "$i. Step $i"
    echo '```bash'
    echo "echo step-$i"
    echo '```'
  done
} > "$REPO2/skills/recipe-skill/SKILL.md"
git -C "$REPO2" add -A
expect_stderr_contains "G2 —" "unwrapped step-list recipe is flagged (advisory)" \
  bash -c "cd '$REPO2' && '$CHECK' --staged"
expect_exit 0 "warn stage: G2 finding does not fail the build" \
  bash -c "cd '$REPO2' && '$CHECK' --staged"

echo "== G2: when/dry-run/gate wrapper with a home-variable call => not flagged"
REPO3="$TMP/repo3"
mk_repo "$REPO3"
git -C "$REPO3" commit -q --allow-empty -m "root"
mkdir -p "$REPO3/skills/wrapper-skill"
cat > "$REPO3/skills/wrapper-skill/SKILL.md" <<'EOF'
---
name: wrapper-skill
description: wraps a program
---
When: on demand. Dry-run: pass `--dry-run`. Gate: none needed. Verify: exit 0.

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/wrapper/scripts/prog.sh" --dry-run
```
EOF
git -C "$REPO3" add -A
OUT3="$(cd "$REPO3" && "$CHECK" --staged 2>&1)"
if ! grep -q "G2 —" <<<"$OUT3"; then ok "wrapped program is not flagged by G2"; else bad "wrapped program is not flagged by G2" "$OUT3"; fi

echo "== STAGE=fail-new: a newly added file with a G3 violation fails the build"
REPO4="$TMP/repo4"
mk_repo "$REPO4"
git -C "$REPO4" commit -q --allow-empty -m "root"
mkdir -p "$REPO4/skills/bad-skill"
cat > "$REPO4/skills/bad-skill/SKILL.md" <<'EOF'
---
name: bad-skill
description: cwd-relative
---
```bash
bash skills/bad-skill/scripts/run.sh
```
EOF
git -C "$REPO4" add -A
PROCEDURE_SKILLS_STAGE=fail-new
export PROCEDURE_SKILLS_STAGE
expect_exit 1 "fail-new stage: newly added G3 violation fails" \
  bash -c "cd '$REPO4' && PROCEDURE_SKILLS_STAGE=fail-new '$CHECK' --staged"
unset PROCEDURE_SKILLS_STAGE

echo "== AGENTS.md is also scanned for G3"
REPO5="$TMP/repo5"
mk_repo "$REPO5"
git -C "$REPO5" commit -q --allow-empty -m "root"
printf 'run: `bash .eposforge/x/scripts/y.sh`\n' > "$REPO5/AGENTS.md"
git -C "$REPO5" add -A
expect_stderr_contains "AGENTS.md" "AGENTS.md scanned for G3" \
  bash -c "cd '$REPO5' && '$CHECK' --staged"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
