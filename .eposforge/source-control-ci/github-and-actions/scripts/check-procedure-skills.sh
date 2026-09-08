#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# check-procedure-skills.sh — Gates G2 and G3 (Standard 15 / Standard 03).
#
#   G3  No cwd-relative program invocation in a SKILL.md or in always-loaded
#       instructions (AGENTS.md): a literal `bash .eposforge/` or
#       `bash skills/` with no `${EPOSFORGE_HOME:?...}` (or another documented
#       home variable) in front of it.
#
#   G2  A procedure `skills/*/SKILL.md` whose body is a numbered executable
#       recipe (several ```bash steps under a numbered list) must invoke a
#       program via a documented home variable rather than being the only
#       place the steps exist.
#
# Ratchet stage (EF-090 plan "Ratchet"; backlog EF-090 Verify-with): both
# gates land in **warn** mode for v1 — they report, they do not fail the
# build. G2 in particular must not ship as a guessed heuristic that fails
# builds (a false positive on a judgment skill is how a gate gets disabled).
# Set PROCEDURE_SKILLS_STAGE to move along the ratchet once examples have
# been operator-reviewed:
#
#   warn           (default) report only, always exit 0
#   fail-new       fail only for files ADDED in the scanned diff
#   fail-touched   fail for any file touched in the scanned diff
#   fail-remaining fail for any violation anywhere in the scan set
#
# Modes (orthogonal to stage — what to scan):
#   --staged                     Staged content (for pre-commit)
#   --changed-against <git-ref>  Files changed since ref (for CI)
#   (default)                    Every tracked file in the scan set
#
# Invoked from:
#   * pre-commit hook fragment at
#     .eposforge/source-control-ci/github-and-actions/scripts/hooks/pre-commit
#   * CI workflow .github/workflows/program-first-gates.yml
#
# Cross-host: runs on Linux (srv-docker-hp) and Windows Git Bash (ws-dev-1).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MODE="all"
BASE_REF=""
if [[ "${1:-}" == "--staged" ]]; then
  MODE="staged"
elif [[ "${1:-}" == "--changed-against" ]]; then
  MODE="changed"
  BASE_REF="${2:-}"
  if [[ -z "${BASE_REF}" ]]; then
    echo "ERROR: --changed-against requires a git ref" >&2
    exit 1
  fi
fi

STAGE="${PROCEDURE_SKILLS_STAGE:-warn}"
case "$STAGE" in
  warn|fail-new|fail-touched|fail-remaining) ;;
  *) echo "ERROR: PROCEDURE_SKILLS_STAGE must be warn|fail-new|fail-touched|fail-remaining" >&2; exit 1 ;;
esac

# Files this checker looks at at all: SKILL.md under skills/*, plus AGENTS.md.
in_scan_set() {
  case "$1" in
    skills/*/SKILL.md|AGENTS.md) return 0 ;;
  esac
  return 1
}

# G3: a literal "bash .eposforge/" or "bash skills/" with no home-variable
# guard in front of it. The conformant form is
# `bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/..."` — the
# non-conformant literal never appears there because the path starts inside
# the expansion, not with a bare `bash .eposforge/`.
g3_violations() {
  grep -nE 'bash \.eposforge/|bash skills/' <<<"$1" || true
}

# G2 heuristic (advisory only while STAGE=warn): a numbered list (lines
# starting "N.") combined with 3+ ```bash fences and no home-variable
# invocation anywhere in the file looks like a step-list recipe rather than a
# thin wrapper. This is intentionally coarse — see the module docstring.
g2_looks_like_unwrapped_recipe() {
  local content="$1"
  local numbered_steps bash_fences home_var_hits
  numbered_steps="$(grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]' <<<"$content" || true)"
  bash_fences="$(grep -cE '^```(bash|sh)\b' <<<"$content" || true)"
  home_var_hits="$(grep -cE '\$\{[A-Z_]+_HOME(:\?[^}]*)?\}' <<<"$content" || true)"
  [[ "${numbered_steps:-0}" -ge 3 && "${bash_fences:-0}" -ge 3 && "${home_var_hits:-0}" -eq 0 ]]
}

declare -a g3_hits=()
declare -a g2_hits=()
declare -a scanned_new=()   # files added in this diff (for fail-new)
declare -a scanned_touched=() # files touched in this diff (for fail-touched)

record_findings() {
  local label="$1" content="$2"
  local g3
  g3="$(g3_violations "$content")"
  if [[ -n "$g3" ]]; then
    g3_hits+=("${label}:"$'\n'"${g3}")
  fi
  if [[ "$label" == skills/*/SKILL.md ]] && g2_looks_like_unwrapped_recipe "$content"; then
    g2_hits+=("$label")
  fi
}

if [[ "$MODE" == "staged" ]]; then
  while IFS= read -r -d '' f; do
    in_scan_set "$f" || continue
    git cat-file -e ":${f}" 2>/dev/null || continue
    scanned_new+=("$f")
    scanned_touched+=("$f")
    record_findings "$f" "$(git show ":${f}")"
  done < <(git diff --cached --name-only --diff-filter=A -z)
  # CMR, not ACMR: A is scanned above. ACMR here would re-run record_findings
  # on every added file a second time (A is a subset of ACMR), duplicating
  # every finding in the output. scanned_touched still ends up with the full
  # added+copied+modified+renamed set across both loops.
  while IFS= read -r -d '' f; do
    in_scan_set "$f" || continue
    git cat-file -e ":${f}" 2>/dev/null || continue
    scanned_touched+=("$f")
    record_findings "$f" "$(git show ":${f}")"
  done < <(git diff --cached --name-only --diff-filter=CMR -z)
elif [[ "$MODE" == "changed" ]]; then
  while IFS= read -r -d '' f; do
    in_scan_set "$f" || continue
    [[ -f "$f" ]] || continue
    scanned_new+=("$f")
    scanned_touched+=("$f")
    record_findings "$f" "$(cat "$f")"
  done < <(git diff --name-only --diff-filter=A -z "${BASE_REF}...HEAD")
  # CMR, not ACMR — see the staged-mode loop above for why.
  while IFS= read -r -d '' f; do
    in_scan_set "$f" || continue
    [[ -f "$f" ]] || continue
    scanned_touched+=("$f")
    record_findings "$f" "$(cat "$f")"
  done < <(git diff --name-only --diff-filter=CMR -z "${BASE_REF}...HEAD")
else
  while IFS= read -r -d '' f; do
    in_scan_set "$f" || continue
    [[ -f "$f" ]] || continue
    scanned_new+=("$f")
    scanned_touched+=("$f")
    record_findings "$f" "$(cat "$f")"
  done < <(git ls-files -z)
fi

has_findings=0
if [[ "${#g3_hits[@]}" -gt 0 || "${#g2_hits[@]}" -gt 0 ]]; then
  has_findings=1
  echo "" >&2
  echo "check-procedure-skills.sh (stage=${STAGE}, mode=${MODE}):" >&2
  if [[ "${#g3_hits[@]}" -gt 0 ]]; then
    echo "" >&2
    echo "G3 — cwd-relative invocation (must use the documented home variable instead):" >&2
    for h in "${g3_hits[@]}"; do echo "  $h" >&2; done
  fi
  if [[ "${#g2_hits[@]}" -gt 0 ]]; then
    echo "" >&2
    echo "G2 — looks like a numbered step-list recipe with no program invocation" >&2
    echo "     via a home variable (advisory — confirm by hand before treating as a" >&2
    echo "     defect; a judgment skill can look like this and be correct as-is):" >&2
    for h in "${g2_hits[@]}"; do echo "  $h" >&2; done
  fi
fi

if [[ "$has_findings" -eq 0 ]]; then
  echo "G2/G3 procedure-skills check passed (stage=${STAGE}, mode=${MODE})."
  exit 0
fi

case "$STAGE" in
  warn)
    echo "" >&2
    echo "STAGE=warn: reporting only, not failing the build (see Ratchet, Standard 15)." >&2
    exit 0
    ;;
  fail-new)
    for f in "${scanned_new[@]}"; do
      for h in "${g3_hits[@]}" "${g2_hits[@]}"; do
        [[ "$h" == "$f"* ]] && { echo "" >&2; echo "STAGE=fail-new: failing on added file $f" >&2; exit 1; }
      done
    done
    echo "" >&2
    echo "STAGE=fail-new: findings exist only in already-touched (not newly added) files; not failing." >&2
    exit 0
    ;;
  fail-touched)
    echo "" >&2
    echo "STAGE=fail-touched: failing — findings in touched files." >&2
    exit 1
    ;;
  fail-remaining)
    echo "" >&2
    echo "STAGE=fail-remaining: failing — findings anywhere in the scan set." >&2
    exit 1
    ;;
esac
