#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# check-operating-inference.sh — Gate G4 (Standard 15 / EF-089): every
# allowlisted Living Spec declares `operating_inference`, and a
# `continuous-loop` declaration carries both a reason and a budget pointer.
#
# Scan set (v1, deliberately a two-file allowlist — EF-089's plan "Scan-set
# discipline"; do NOT grep for the words "Living Spec", many adapter docs use
# the phrase without being governed by this contract):
#   * .eposforge/SPEC.md
#   * .eposforge/backlog/file-based-backlog/file-based-backlog.md
#
# Unlike G1/G2/G3 this gate is not diff-scoped: the allowlist is small and
# fixed, so both files are always checked outright. It applies as soon as the
# field exists in the contract (EF-090 plan "Ratchet") — no warn stage.
#
# Modes:
#   --staged   Read each allowlisted file from the git index (what is about
#              to be committed), not the working tree — a file untouched by
#              this commit is still read from the index, which mirrors HEAD
#              for anything not staged. This is what makes pre-commit check
#              what will actually be committed rather than whatever happens
#              to be on disk at the same moment.
#   (default)  Read from the working tree (for CI, where the checkout IS the
#              tree being validated).
#
# Invoked from:
#   * pre-commit hook fragment at
#     .eposforge/source-control-ci/github-and-actions/scripts/hooks/pre-commit
#     (with --staged)
#   * CI workflow .github/workflows/program-first-gates.yml (no args)
#
# Cross-host: runs on Linux (srv-docker-hp) and Windows Git Bash (ws-dev-1).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

STAGED=0
if [[ "${1:-}" == "--staged" ]]; then
  STAGED=1
fi

ALLOWLIST=(
  ".eposforge/SPEC.md"
  ".eposforge/backlog/file-based-backlog/file-based-backlog.md"
)

VALID_VALUES="none on-demand-judgment continuous-loop"

is_valid_value() {
  local v="$1" c
  for c in $VALID_VALUES; do
    [[ "$v" == "$c" ]] && return 0
  done
  return 1
}

# Prints file content on stdout; returns 1 if the file does not exist in the
# selected source (working tree, or git index) — "not this gate's problem"
# for an allowlisted file that has not been created yet.
read_allowlisted() {
  local f="$1"
  if [[ "$STAGED" -eq 1 ]]; then
    git cat-file -e ":${f}" 2>/dev/null || return 1
    git show ":${f}"
  else
    [[ -f "$f" ]] || return 1
    cat "$f"
  fi
}

errors=()

for f in "${ALLOWLIST[@]}"; do
  content="$(read_allowlisted "$f")" || continue

  line="$(grep -m1 -E '`operating_inference`' <<<"$content" || true)"
  if [[ -z "$line" ]]; then
    errors+=("$f: no \`operating_inference\` field found")
    continue
  fi

  # Table row shape: | `operating_inference` | `<value>` — prose |
  #
  # Anchored, not a scan for "any backtick-quoted word on the line": that
  # approach (tried and reverted — see EF-090 round 2 review) still passed a
  # malformed value cell like `none|foo` - `none` by picking up a coincidental
  # valid-looking backtick token from the row's own prose. \K discards
  # everything matched so far, so the [a-z-]+ capture must begin exactly at
  # the value cell's opening backtick and, bounded by the closing backtick
  # lookahead, cannot span or skip past a stray '|' inside that cell. A
  # malformed cell therefore yields no match at all here, not a wrong one.
  value="$(grep -oP '`operating_inference`[[:space:]]*\|[[:space:]]*`\K[a-z-]+(?=`)' <<<"$line" || true)"

  if [[ -z "$value" ]] || ! is_valid_value "$value"; then
    errors+=("$f: \`operating_inference\` value '${value}' is not one of: ${VALID_VALUES}")
    continue
  fi

  if [[ "$value" == "continuous-loop" ]]; then
    if ! grep -q -E '`operating_inference_reason`' <<<"$content"; then
      errors+=("$f: declares continuous-loop but has no \`operating_inference_reason\`")
    fi
    if ! grep -q -E '`operating_inference_budget`' <<<"$content"; then
      errors+=("$f: declares continuous-loop but has no \`operating_inference_budget\`")
    fi
  fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
  cat >&2 <<'MSG'
ERROR: G4 (Standard 15 / EF-089) — operating_inference non-conformance.

Every allowlisted Living Spec must declare `operating_inference` as one of
none | on-demand-judgment | continuous-loop. A `continuous-loop` declaration
is non-conformant without a written `operating_inference_reason` and a
pointer to a budget policy in `operating_inference_budget`.

See 01-architecture/02-components/living-spec.md and
.eposforge/backlog/plans/EF-089-living-spec-operating-inference.md.
MSG
  echo "" >&2
  for e in "${errors[@]}"; do echo "  $e" >&2; done
  exit 1
fi

echo "G4 operating_inference check passed."
