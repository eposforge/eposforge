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
# ── Why invalid has two exit codes ───────────────────────────────────────────
# A reviewer that emits a plausible synonym for a property name has still done
# the review. Refusing that payload is right — it does not conform, so it is not
# a verdict — but discarding the round over a key name is not, and the only
# recovery used to be a human renaming the field by hand, which puts the author
# in the position of editing the reviewer's answer.
#
# So invalid is split by *what* is wrong, and the split is the safety boundary:
#
#   3  shape only — the JSON Schema rejected it and nothing else did. Nobody's
#      judgment is missing; the payload is the wrong shape. A caller MAY re-ask
#      the same reviewer once with these errors appended.
#   1  substantive — a cross-field rule broke: a claim has no verdict, a verdict
#      names a claim that does not exist, the round does not match, the budget
#      is over. These say something about the review's CONTENT. A caller must
#      NEVER re-ask on these, because "every claim got a verdict" is the check
#      that stops an author shipping unreviewed work, and a retry loop around it
#      would let a reviewer be asked again until it produced a pass.
#
# A payload that trips both is substantive (1). Shape-only is the narrow case,
# and it is narrow on purpose.
#
# 3 is reachable for `findings` ONLY. A handoff and a disposition have no remote
# author to re-ask, so a shape failure in either is a bug in whatever wrote it.
#
# Exit: 0 valid · 1 invalid (substantive) · 3 invalid, findings, schema shape
#       only · 2 usage / unreadable input.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB="$SCRIPT_DIR/lib/jsonschema.jq"

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

die()  { echo "validate-payload: $*" >&2; exit 2; }

# PHASE tags every failure with the region that raised it, so the exit code can
# distinguish "wrong shape" from "wrong answer". Anything raised while PHASE is
# `cross` is substantive and forecloses a re-ask.
PHASE=schema
# Cross-field failures are raised here, in bash, rather than by the schema
# library, so they have no JSON pointer to report. They are still collected for
# --json-errors (eposforge:EF-079) with the phase that raised them — a caller
# that acts only on `schema`-phase errors must be able to see that substantive
# failures were also present, not infer it from their absence.
CROSS_MSGS=()
fail() {
  echo "INVALID: $*" >&2
  FAILED=1
  if [[ "$PHASE" == cross ]]; then
    CROSS_FAILED=1
    CROSS_MSGS+=("$*")
  fi
  return 0
}

KIND="${1:-}"; shift || usage
FILE="${1:-}"; shift || usage
[[ -n "$KIND" && -n "$FILE" ]] || usage

FINAL=0
SCHEMA_ONLY=0
JSON_ERRORS=0
REF_HANDOFF=""
REF_FINDINGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --final)    FINAL=1; shift ;;
    --schema-only) SCHEMA_ONLY=1; shift ;;
    --json-errors) JSON_ERRORS=1; shift ;;
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
CROSS_FAILED=0
SCHEMA_ERR_JSON='[]'

# --json-errors (eposforge:EF-079): a second CHANNEL, never a second verdict.
# It writes one JSON object to stdout; the `INVALID:` lines still go to stderr
# unchanged, and — this is the part that matters — the exit code is computed
# exactly as it is without the flag and is passed in here rather than derived.
# There is deliberately no code path in which asking for machine-readable errors
# can turn a refusal into a pass.
emit_json_errors() {
  (( JSON_ERRORS )) || return 0
  local code="$1"
  jq -n -c \
    --argjson schema_errors "$SCHEMA_ERR_JSON" \
    --arg kind "$KIND" --arg file "$FILE" \
    --argjson code "$code" \
    --args '
      {
        schema: "eposforge.crosscheck.validation-errors/1",
        kind: $kind,
        file: $file,
        valid: ($code == 0),
        exit: $code,
        errors: (
          ($schema_errors | map(. + {phase: "schema"}))
          + ($ARGS.positional | map({
              path: null, pointer: null, keyword: null,
              message: ., phase: "cross"
            }))
        )
      }' "${CROSS_MSGS[@]+"${CROSS_MSGS[@]}"}"
}

# The `ok` lines are the only human output that ever went to stdout. Under
# --json-errors stdout belongs to the JSON object, so they move to stderr — but
# ONLY in that mode. A caller that does not pass the flag sees byte-identical
# output to before EF-079, which is what "adds a channel rather than replacing
# one" has to mean in practice.
say_ok() {
  if (( JSON_ERRORS )); then echo "$*" >&2; else echo "$*"; fi
}

# ── 1. Schema ────────────────────────────────────────────────────────────────
ERRORS="$(jq -r --slurpfile s "$SCHEMA" -L "$SCRIPT_DIR/lib" \
  'include "jsonschema"; jsonschema_errors($s[0])[]' "$FILE" 2>&1)"
if [[ -n "$ERRORS" ]]; then
  while IFS= read -r line; do fail "$line"; done <<<"$ERRORS"
fi
# Computed only when asked: validate runs on every claim append, and a second
# pass over the schema on that hot path would be paid by everyone to benefit
# the rare caller that wants structure.
if (( JSON_ERRORS )); then
  SCHEMA_ERR_JSON="$(jq -c --slurpfile s "$SCHEMA" -L "$SCRIPT_DIR/lib" \
    'include "jsonschema"; jsonschema_error_objects($s[0])' "$FILE" 2>/dev/null)"
  [[ -z "$SCHEMA_ERR_JSON" ]] && SCHEMA_ERR_JSON='[]'
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
    # Stays 1, not 3. In this mode every failure is a shape failure by
    # construction, so the shape/substance split carries no information — and
    # the append helper only asks whether it may keep writing.
    emit_json_errors 1
    echo "validate-payload: $KIND $FILE — INVALID (schema only)" >&2
    exit 1
  fi
  emit_json_errors 0
  say_ok "validate-payload: $KIND $FILE — ok (schema only)"
  exit 0
fi

PHASE=cross

case "$KIND" in
handoff)
  check_budget "${CROSSCHECK_HANDOFF_TOKEN_CAP:-8000}"

  dupes="$(jq -r '[.claims[].id] | group_by(.)[] | select(length > 1) | .[0]' "$FILE")"
  [[ -n "$dupes" ]] && while IFS= read -r d; do fail "duplicate claim id: $d"; done <<<"$dupes"

  if (( FINAL )); then
    for f in coverage check_results reviewer_resolved prompt_sha256; do
      jq -e --arg f "$f" 'has($f)' "$FILE" >/dev/null || fail "--final: missing $f"
    done

    # The revisions this payload promises must still exist and still be on their
    # branch. Checked by reading the field rather than by touching git, so this
    # script stays pure — but the field can only be written by
    # crosscheck-verify-scope.sh, so it cannot be finalised without that running.
    unverified="$(jq -r '.scope[] | select((.integrity // "") == "") | .repo_path' "$FILE")"
    [[ -n "$unverified" ]] && while IFS= read -r u; do
      fail "--final: scope entry $u has no integrity verdict — run crosscheck-verify-scope.sh --write"
    done <<<"$unverified"

    drifted="$(jq -r '.scope[] | select((.integrity // "ok") != "ok") | "\(.repo_path) [\(.integrity)]"' "$FILE")"
    [[ -n "$drifted" ]] && while IFS= read -r d; do
      fail "--final: scope drift, the reviewer cannot be handed what this promises: $d"
    done <<<"$drifted"

    # Without the disposition leg, round N+1 re-asserts instead of answering,
    # and "both agents agree" is unreachable by construction.
    round="$(jq -r '.round' "$FILE")"
    if [[ "$round" =~ ^[0-9]+$ ]] && (( round > 1 )); then
      dref="$(jq -r '.disposition_ref // empty' "$FILE")"
      if [[ -z "$dref" ]]; then
        fail "--final: round $round carries no disposition_ref — the previous round's findings were never answered"
      else
        dabs="$dref"; [[ "$dabs" == /* ]] || dabs="$FILE_DIR/$dref"
        [[ -r "$dabs" ]] || fail "--final: disposition_ref points at $dref, which cannot be read"
      fi
    fi
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
  check_budget "${CROSSCHECK_FINDINGS_TOKEN_CAP:-6000}"

  href="$REF_HANDOFF"
  if [[ -z "$href" ]]; then
    href="$(resolve_ref "$FILE_DIR" "$(jq -r '.handoff_ref // empty' "$FILE")")" || true
  fi
  if [[ -z "$href" || ! -r "$href" ]]; then
    fail "cannot read the handoff this answers (handoff_ref=$(jq -r '.handoff_ref // "null"' "$FILE")); claim coverage is unverifiable"
  else
    hr="$(jq -r '.round' "$href")"; fr="$(jq -r '.round' "$FILE")"
    [[ "$hr" == "$fr" ]] || fail "round mismatch: these findings say round $fr, the handoff they answer says round $hr"

    uncovered="$(jq -r -n --slurpfile h "$href" --slurpfile f "$FILE" '
      [ $h[0].claims[].id ] as $claims
      | [ $f[0].claims_verified[].claim_id ] as $seen
      | ( ($claims - $seen) | map("uncovered claim: " + .) )
      + ( ($seen - $claims) | map("verdict for unknown claim: " + .) )
      + ( [ $seen | group_by(.)[] | select(length > 1) | "duplicate verdict for claim: " + .[0] ] )
      | .[]' 2>&1)"
    [[ -n "$uncovered" ]] && while IFS= read -r u; do fail "$u"; done <<<"$uncovered"

    # A finding may only point at a claim the handoff actually declares.
    # Bind the finding before the pipe: inside `$claims | index(...)` the input
    # is the claims array, so `.claim_ref` there is an index into an array and
    # jq aborts — which made every payload that used claim_ref read INVALID for
    # a reason that had nothing to do with the payload.
    bad="$(jq -r -n --slurpfile h "$href" --slurpfile f "$FILE" '
      [ $h[0].claims[].id ] as $claims
      | $f[0].findings[]
      | . as $fnd
      | select(($fnd.claim_ref // "") != "")
      | select(($claims | index($fnd.claim_ref)) == null)
      | "finding " + $fnd.id + " references unknown claim " + $fnd.claim_ref' 2>&1)"
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
    fr="$(jq -r '.round' "$fref")"; dr="$(jq -r '.round' "$FILE")"
    [[ "$fr" == "$dr" ]] || fail "round mismatch: this disposition says round $dr, the findings it answers say round $fr"

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
  # Only `findings` can be shape-only, because only `findings` has an author who
  # can be re-asked. A handoff and a disposition are written by the harness and
  # the work's author, so a shape failure there is a bug to fix in the writer,
  # not a payload to request again — reporting 3 would offer a recovery that
  # does not exist.
  if (( CROSS_FAILED )) || [[ "$KIND" != findings ]]; then
    emit_json_errors 1
    echo "validate-payload: $KIND $FILE — INVALID" >&2
    exit 1
  fi
  # Shape alone. Every claim still carries a verdict; the reviewer's judgment is
  # intact and only the container is wrong. See the header for what a caller may
  # and may not do with this.
  emit_json_errors 3
  echo "validate-payload: $KIND $FILE — INVALID (schema shape only)" >&2
  exit 3
fi
emit_json_errors 0
say_ok "validate-payload: $KIND $FILE — ok"
exit 0
