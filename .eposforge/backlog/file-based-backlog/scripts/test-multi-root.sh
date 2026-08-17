#!/usr/bin/env bash
# test-multi-root.sh — eposforge:EF-078 regression suite.
#
# Builds a THROWAWAY three-root fixture in a temp dir and asserts that one
# invocation of lint-backlog.sh / sweep-resolved.sh acts on every root, without
# trading the false positive it removes for a false negative.
#
# The fixture uses all three supported layouts on purpose — `<repo>/backlog`,
# `<repo>/.eposforge/backlog`, `<repo>/eposforge/backlog` — because root
# resolution probes them in that order and a bug that only handles the flat
# layout would otherwise pass.
#
# Every positive case is paired with a negative control: the assertion that a
# check still FAILS when it should. A suite of green-only cases cannot tell a
# working check from a disabled one, which is precisely the failure mode EF-078
# warns against ("the fix must not be 'stop checking'").
#
# Usage: test-multi-root.sh          # run all cases
#        KEEP=1 test-multi-root.sh   # leave the fixture in place for inspection

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${SCRIPTS_DIR}/lint-backlog.sh"
SWEEP="${SCRIPTS_DIR}/sweep-resolved.sh"

# A test suite must not inherit the caller's crosscheck round/session — a claim
# that runs this suite would otherwise appear to belong to whatever round the
# environment last named.
unset CROSSCHECK_ROUND CROSSCHECK_SESSION 2>/dev/null || true
# Likewise the caller's own root set, or the fixture would be linted alongside
# the real repos and every assertion below would be about the wrong files.
unset BACKLOG_ROOTS VSCODE_WORKSPACE_FILE WORKSPACE_FILE 2>/dev/null || true

pass=0
fail=0

ok()   { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '       %s\n' "$2"; }

# assert_contains <name> <haystack> <needle>
assert_contains() {
  if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1" "expected to find: $3"; fi
}
# assert_not_contains <name> <haystack> <needle>
assert_not_contains() {
  if [[ "$2" != *"$3"* ]]; then ok "$1"; else bad "$1" "expected NOT to find: $3"; fi
}
# assert_eq <name> <actual> <expected>
assert_eq() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "got '$2', want '$3'"; fi
}

FIXTURE="$(mktemp -d -t ef078-XXXXXX)"
cleanup() { [[ -n "${KEEP:-}" ]] && { echo "fixture kept: ${FIXTURE}"; return; }; rm -rf "${FIXTURE}"; }
trap cleanup EXIT

# ---------------------------------------------------------------- fixture ----

# mk_config <backlog-dir> <prefix> <visibility>
mk_config() {
  cat > "$1/config.toml" <<EOF
prefix = "$2"
visibility = "$3"
fix_surfaces = ["process", "tooling"]
tags = ["alpha", "beta"]
EOF
}

# mk_root <repo-name> <layout-subdir-or-empty> <prefix> <visibility>
mk_root() {
  local repo="${FIXTURE}/$1" sub="$2" dir
  dir="${repo}${sub:+/$sub}/backlog"
  mkdir -p "${dir}"
  mk_config "${dir}" "$3" "$4"
  printf '# Backlog\n\n' > "${dir}/backlog.md"
  printf '# Slated\n\n'  > "${dir}/backlog-slated.md"
  printf '# Backlog Archive\n\n' > "${dir}/backlog-archive.md"
  # Each root is its own git repo: lint resolves display paths against the git
  # toplevel, and sweep asks git for it too.
  git -C "${repo}" init -q 2>/dev/null
  git -C "${repo}" config user.email t@t.invalid
  git -C "${repo}" config user.name t
  echo "${dir}"
}

# add_issue <backlog-file> <id> <title> <status> [extra field lines...]
add_issue() {
  local file="$1" id="$2" title="$3" status="$4"; shift 4
  {
    printf '## Issue %s — %s\n' "$id" "$title"
    printf 'ID: %s\n' "$id"
    printf 'Title: %s\n' "$title"
    printf 'Date: 2026-08-17\n'
    printf 'Status: %s\n' "$status"
    printf 'Effort: S\n'
    printf 'Fix surface: process\n'
    printf 'Tags: alpha\n'
    for line in "$@"; do printf '%s\n' "$line"; done
    printf 'Verify with: it verifies.\n'
    printf '\n'
  } >> "${file}"
}

A_DIR="$(mk_root repoA ""            AA public)"
B_DIR="$(mk_root repoB ".eposforge"  BB private)"
C_DIR="$(mk_root repoC "eposforge"   CC private)"

# repoA is PUBLIC, so it carries no outbound cross-repo edges (EF-047 direction).
add_issue "${A_DIR}/backlog.md" AA-001 "Public anchor" open

# repoB (private) points at the public root, and uses `Status: blocked` with a
# dependency that exists ONLY in another repo — the case EF-078 folds in.
add_issue "${B_DIR}/backlog.md" BB-001 "Private work" open "Depends on: repoA:AA-001"
add_issue "${B_DIR}/backlog.md" BB-002 "Blocked cross-repo" blocked "Depends on: repoA:AA-001"

# repoC (private) is the THIRD root and holds the resolved item, so sweeping it
# exercises exactly the non-first-root case.
add_issue "${C_DIR}/backlog.md" CC-001 "Done thing" resolved \
  "Resolved: 2026-08-17" "Validation: verified by hand."
add_issue "${C_DIR}/backlog.md" CC-002 "Chained" open "Depends on: repoB:BB-001"

ROOTS="${FIXTURE}/repoA:${FIXTURE}/repoB:${FIXTURE}/repoC"

# ------------------------------------------------------------------ cases ----

echo "--- lint: one invocation covers every root ---"

out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "lint exits 0 across three cross-referencing roots" "${rc}" "0"
assert_not_contains "no unknown-ID error for a link that resolves elsewhere" \
  "${out}" "unknown issue ID"
assert_contains "resolved item in the THIRD root is seen (warning)" \
  "${out}" "CC-001 is resolved"
assert_contains "findings are qualified by repo when multi-root" "${out}" "repoC/"

# The blocked fold-in: BB-002's only dependency is `repoA:AA-001`.
assert_not_contains "Status: blocked satisfied by a cross-repo-only dependency" \
  "${out}" "BB-002 \`Status: blocked\` requires"

echo "--- negative controls: the checks still fail when they should ---"

# 1. A link that resolves in NO root must still error.
add_issue "${C_DIR}/backlog.md" CC-003 "Dangling" open "Depends on: repoB:BB-999"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "a genuinely dangling link still fails the run" "${rc}" "1"
assert_contains "and names the offending ID" "${out}" "BB-999"
# Control the control: it is the dangling link that broke it, nothing else.
sed -i '/^Depends on: repoB:BB-999$/d; /CC-003/d; /^Title: Dangling$/d' "${C_DIR}/backlog.md"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "removing only that link makes the run green again" "${rc}" "0"

# 2. `Status: blocked` must still fail when the dependency resolves nowhere.
cp "${B_DIR}/backlog.md" "${FIXTURE}/B.bak"
sed -i 's|^Depends on: repoA:AA-001$|Depends on: repoA:AA-404|' "${B_DIR}/backlog.md"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "blocked with an unresolvable dependency still fails" "${rc}" "1"
assert_contains "blocked check is not simply disabled" "${out}" "Status: blocked\` requires"
cp "${FIXTURE}/B.bak" "${B_DIR}/backlog.md"

# 3. A per-root vocabulary error in a NON-FIRST root must be caught. Before
#    EF-078 this file was never opened, so this case could not fail.
cp "${C_DIR}/backlog.md" "${FIXTURE}/C.bak"
sed -i '0,/^Fix surface: process$/s//Fix surface: not-a-surface/' "${C_DIR}/backlog.md"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "an invalid Fix surface in the third root fails the run" "${rc}" "1"
assert_contains "and is attributed to that root" "${out}" "repoC/"
cp "${FIXTURE}/C.bak" "${C_DIR}/backlog.md"

# 4. The public root is still leak-scanned, and the private ones still are not.
printf '\n<!-- see /mnt/raid-storage/secret -->\n' >> "${A_DIR}/backlog.md"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "a host path in the PUBLIC root fails the run" "${rc}" "1"
assert_contains "reported as a public-repo leak" "${out}" "public-repo leak"
sed -i '/mnt\/raid-storage\/secret/d' "${A_DIR}/backlog.md"
printf '\n<!-- see /mnt/raid-storage/secret -->\n' >> "${B_DIR}/backlog.md"
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${LINT}" 2>&1)"; rc=$?
assert_eq "the same path in a PRIVATE root does not" "${rc}" "0"
sed -i '/mnt\/raid-storage\/secret/d' "${B_DIR}/backlog.md"

echo "--- sweep: a resolved item in a NON-FIRST root ---"

out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${SWEEP}" 2>&1)"; rc=$?
assert_eq "sweep exits 0 with repoC third in the list" "${rc}" "0"
assert_contains "sweep reports the move" "${out}" "moved 1 issue(s)"
assert_not_contains "CC-001 has left the active file" \
  "$(cat "${C_DIR}/backlog.md")" "## Issue CC-001"
assert_contains "CC-001 is in repoC's archive" \
  "$(cat "${C_DIR}/backlog-archive.md")" "## Issue CC-001"
assert_contains "archived under its resolved month" \
  "$(cat "${C_DIR}/backlog-archive.md")" "## 2026-08"
assert_contains "the archive index was regenerated" \
  "$(cat "${C_DIR}/backlog-archive-index.md")" "CC-001"
assert_not_contains "the first root's active file was not disturbed" \
  "$(cat "${A_DIR}/backlog.md")" "CC-001"

# Negative control for sweep: it must still refuse to run when lint errors.
add_issue "${C_DIR}/backlog.md" CC-004 "Dangling again" open "Depends on: repoB:BB-999"
add_issue "${B_DIR}/backlog.md" BB-003 "Also resolved" resolved \
  "Resolved: 2026-08-17" "Validation: verified."
out="$(cd "${FIXTURE}" && BACKLOG_ROOTS="${ROOTS}" "${SWEEP}" 2>&1)"; rc=$?
assert_eq "sweep still aborts on any lint error" "${rc}" "1"
assert_contains "BB-003 was NOT archived while lint was red" \
  "$(cat "${B_DIR}/backlog.md")" "## Issue BB-003"

echo "--- single-root behaviour is unchanged ---"

out="$(cd "${FIXTURE}/repoA" && "${LINT}" 2>&1)"; rc=$?
assert_eq "single root, no BACKLOG_ROOTS, still lints" "${rc}" "0"
assert_not_contains "single-root output is NOT repo-qualified" "${out}" "repoA/backlog"

# The documented single-root degradation: repoB alone cannot resolve repoA's IDs.
out="$(cd "${FIXTURE}/repoB" && "${LINT}" 2>&1)"; rc=$?
assert_eq "a private root alone still reports its cross-repo link as unknown" "${rc}" "1"
assert_contains "which is the documented degradation, not a regression" \
  "${out}" "unknown issue ID"

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
