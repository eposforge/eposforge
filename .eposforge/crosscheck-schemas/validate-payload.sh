#!/usr/bin/env bash
# validate-payload.sh — structural + cross-field validation of a cross-check payload.
#
#   validate-payload.sh handoff     <file> [--final]
#   validate-payload.sh findings    <file> [--handoff <file>]
#   validate-payload.sh disposition <file> [--findings <file>]
#
# Pure bash + jq. Schema validation runs against the JSON Schema files in this
# directory, so the schema stays the single source of truth for shape and
# vocabulary; this script adds only the rules a schema cannot express.
#
# Cross-field rules enforced here:
#   handoff     — budget.over_budget must be false, and must be true whenever
#                 est_tokens exceeds cap (an under-reported budget is a lie, not
#                 a pass). Every mechanical claim's id must be unique.
#   findings    — claims_verified[] must cover every handoff claim id exactly
#                 once. A missing claim is a malformed payload, not a pass.
#   disposition — dispositions[] must cover every findings[].id exactly once.
#                 (`detail` on accepted-deferred / rejected is a schema rule.)
#
# `--final` additionally requires the fields the harness fills in just before
# transport: coverage, check_results, reviewer_resolved, prompt_sha256.
#
# Exit: 0 valid · 1 invalid · 2 usage / unreadable input.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/jsonschema.jq"

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

die()  { echo "validate-payload: $*" >&2; exit 2; }
fail() { echo "INVALID: $*" >&2; FAILED=1; }

KIND="${1:-}"; shift || usage
FILE="${1:-}"; shift || usage
[[ -n "$KIND" && -n "$FILE" ]] || usage

FINAL=0
SCHEMA_ONLY=0
REF_HANDOFF=""
REF_FINDINGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --final)    FINAL=1; shift ;;
    --schema-only) SCHEMA_ONLY=1; shift ;;
    --handoff)  REF_HANDOFF="$2"; shift 2 ;;
    --findings) REF_FINDINGS="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found"
[[ -r "$LIB" ]] || die "validator library not found at $LIB"
[[ -r "$FILE" ]] || die "cannot read $FILE"

case "$KIND" in
  handoff|findings|disposition) SCHEMA="$SCRIPT_DIR/$KIND.v1.json" ;;
  *) die "unknown payload kind: $KIND (expected handoff|findings|disposition)" ;;
esac
[[ -r "$SCHEMA" ]] || die "schema not found at $SCHEMA"

jq -e . "$FILE" >/dev/null 2>&1 || die "$FILE is not valid JSON"

FAILED=0

# ── 1. Schema ────────────────────────────────────────────────────────────────
ERRORS="$(jq -r --slurpfile s "$SCHEMA" -L "$SCRIPT_DIR/lib" \
  'include "jsonschema"; jsonschema_errors($s[0])[]' "$FILE" 2>&1)"
if [[ -n "$ERRORS" ]]; then
  while IFS= read -r line; do fail "$line"; done <<<"$ERRORS"
fi

# Resolve a payload-relative reference (handoff_ref / findings_ref) against the
# directory of the payload that names it, so a round dir can be moved wholesale.
resolve_ref() {
  local base_dir="$1" ref="$2"
  [[ -z "$ref" || "$ref" == "null" ]] && return 1
  if [[ "$ref" == /* ]]; then printf '%s' "$ref"
  else printf '%s/%s' "$base_dir" "$ref"; fi
}

FILE_DIR="$(cd "$(dirname "$FILE")" && pwd)"

# The budget is a transported field, so it can be stale (coverage and check
# results are appended after the author stops writing) or optimistic. Measure
# the file instead of believing it.
check_budget() {
  local ceiling="$1"
  local cap est measured
  cap="$(jq -r '.budget.cap // empty' "$FILE")"
  est="$(jq -r '.budget.est_tokens // empty' "$FILE")"
  measured=$(( $(wc -c <"$FILE") / 4 ))

  if [[ -n "$cap" ]] && (( cap > ceiling )); then
    fail "budget.cap ($cap) exceeds the configured ceiling ($ceiling) — a payload does not get to raise its own cap"
  fi
  if [[ -n "$cap" ]] && (( measured > cap )); then
    fail "the payload measures ~$measured tokens against a cap of $cap — trim it; truncation is not an option here"
  fi
  if [[ -n "$est" ]] && (( measured > est + est / 10 + 50 )); then
    fail "budget.est_tokens ($est) understates the payload (~$measured) — re-run the writer so the budget describes what is actually being sent"
  fi
  if [[ "$(jq -r '.budget.over_budget // empty' "$FILE")" == "true" ]]; then
    fail "budget.over_budget is true"
  fi
}

# ── 2. Cross-field rules ─────────────────────────────────────────────────────
# --schema-only stops here. It exists for the append helper, which must be able
# to keep writing an over-budget handoff so the author can see what to trim; the
# budget refusal belongs at transport time (--final), not at every append.
if (( SCHEMA_ONLY )); then
  if (( FAILED )); then
    echo "validate-payload: $KIND $FILE — INVALID (schema only)" >&2
    exit 1
  fi
  echo "validate-payload: $KIND $FILE — ok (schema only)"
  exit 0
fi

case "$KIND" in
handoff)
  check_budget "${CROSSCHECK_HANDOFF_TOKEN_CAP:-8000}"

  dupes="$(jq -r '[.claims[].id] | group_by(.)[] | select(length > 1) | .[0]' "$FILE")"
  [[ -n "$dupes" ]] && while IFS= read -r d; do fail "duplicate claim id: $d"; done <<<"$dupes"

  if (( FINAL )); then
    for f in coverage check_results reviewer_resolved prompt_sha256; do
      jq -e --arg f "$f" 'has($f)' "$FILE" >/dev/null || fail "--final: missing $f"
    done
    # Every mechanical claim must have been run before the reviewer is spawned.
    missing="$(jq -r '
      [ .claims[] | select(.class == "mechanical") | .id ] as $m
      | [ (.check_results // [])[] | select(.ran == true) | .claim_id ] as $r
      | ($m - $r)[]' "$FILE")"
    [[ -n "$missing" ]] && while IFS= read -r m; do
      fail "--final: mechanical claim $m has no check_result — run crosscheck-run-checks.sh first"
    done <<<"$missing"
  fi
  ;;

findings)
  check_budget "${CROSSCHECK_FINDINGS_TOKEN_CAP:-4000}"

  href="$REF_HANDOFF"
  if [[ -z "$href" ]]; then
    href="$(resolve_ref "$FILE_DIR" "$(jq -r '.handoff_ref // empty' "$FILE")")" || true
  fi
  if [[ -z "$href" || ! -r "$href" ]]; then
    fail "cannot read the handoff this answers (handoff_ref=$(jq -r '.handoff_ref // "null"' "$FILE")); claim coverage is unverifiable"
  else
    uncovered="$(jq -r -n --slurpfile h "$href" --slurpfile f "$FILE" '
      [ $h[0].claims[].id ] as $claims
      | [ $f[0].claims_verified[].claim_id ] as $seen
      | ( ($claims - $seen) | map("uncovered claim: " + .) )
      + ( ($seen - $claims) | map("verdict for unknown claim: " + .) )
      + ( [ $seen | group_by(.)[] | select(length > 1) | "duplicate verdict for claim: " + .[0] ] )
      | .[]' 2>&1)"
    [[ -n "$uncovered" ]] && while IFS= read -r u; do fail "$u"; done <<<"$uncovered"

    # A finding may only point at a claim the handoff actually declares.
    bad="$(jq -r -n --slurpfile h "$href" --slurpfile f "$FILE" '
      [ $h[0].claims[].id ] as $claims
      | $f[0].findings[]
      | select((.claim_ref // "") != "")
      | select(($claims | index(.claim_ref)) == null)
      | "finding " + .id + " references unknown claim " + .claim_ref' 2>&1)"
    [[ -n "$bad" ]] && while IFS= read -r b; do fail "$b"; done <<<"$bad"
  fi

  dupes="$(jq -r '[.findings[].id] | group_by(.)[] | select(length > 1) | .[0]' "$FILE")"
  [[ -n "$dupes" ]] && while IFS= read -r d; do fail "duplicate finding id: $d"; done <<<"$dupes"
  ;;

disposition)
  fref="$REF_FINDINGS"
  if [[ -z "$fref" ]]; then
    fref="$(resolve_ref "$FILE_DIR" "$(jq -r '.findings_ref // empty' "$FILE")")" || true
  fi
  if [[ -z "$fref" || ! -r "$fref" ]]; then
    fail "cannot read the findings this answers (findings_ref=$(jq -r '.findings_ref // "null"' "$FILE")); finding coverage is unverifiable"
  else
    problems="$(jq -r -n --slurpfile f "$fref" --slurpfile d "$FILE" '
      [ $f[0].findings[].id ] as $found
      | [ $d[0].dispositions[].finding_id ] as $seen
      | ( ($found - $seen) | map("undisposed finding: " + .) )
      + ( ($seen - $found) | map("disposition for unknown finding: " + .) )
      + ( [ $seen | group_by(.)[] | select(length > 1) | "duplicate disposition for finding: " + .[0] ] )
      | .[]' 2>&1)"
    [[ -n "$problems" ]] && while IFS= read -r p; do fail "$p"; done <<<"$problems"
  fi
  ;;
esac

if (( FAILED )); then
  echo "validate-payload: $KIND $FILE — INVALID" >&2
  exit 1
fi
echo "validate-payload: $KIND $FILE — ok"
exit 0
