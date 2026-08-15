#!/usr/bin/env bash
# crosscheck-decide.sh — evaluate the loop termination rule against a findings payload.
#
#   crosscheck-decide.sh <findings.json> [--explain] [--round N] [--max-rounds M]
#
# Prints exactly one word on stdout: stop | continue | halt
#
#   stop      the two agents agree by the rule below; the loop is done
#   continue  another round is owed
#   halt      another round is owed but the round cap is spent; surface to the operator
#
# The rule, and nothing else:
#
#   STOP when
#     no claims_verified[].result == "refuted"
#     AND uncovered_scope[] is empty
#     AND no finding has severity in {blocker, major} with an effective
#         attribution of "introduced-by-change"
#
# It reads only closed-vocabulary fields. `verdict` is deliberately ignored:
# termination must not depend on either agent's opinion that it is done.
#
# Effective attribution: `attribution_checked` (written by the harness after
# running repro_cmd at both revisions) wins over the reviewer's asserted
# `attribution`. When the machine check is absent or "inconclusive", the
# assertion stands and --explain says so — an unsettled attribution is visible,
# not silently resolved in either direction.
#
# Exit: 0 stop · 10 continue · 11 halt · 2 usage / unreadable input.
# (Exit status mirrors the decision so a caller can branch without parsing; the
# word on stdout is the contract.)
set -uo pipefail

FILE=""
EXPLAIN=0
ROUND=""
MAX_ROUNDS="${CROSSCHECK_MAX_ROUNDS:-3}"

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --explain)    EXPLAIN=1; shift ;;
    --round)      ROUND="$2"; shift 2 ;;
    --max-rounds) MAX_ROUNDS="$2"; shift 2 ;;
    -h|--help)    usage ;;
    -*) echo "crosscheck-decide: unknown arg: $1" >&2; usage ;;
    *)  [[ -z "$FILE" ]] || usage; FILE="$1"; shift ;;
  esac
done

[[ -n "$FILE" ]] || usage
command -v jq >/dev/null 2>&1 || { echo "crosscheck-decide: jq not found" >&2; exit 2; }
[[ -r "$FILE" ]] || { echo "crosscheck-decide: cannot read $FILE" >&2; exit 2; }
jq -e . "$FILE" >/dev/null 2>&1 || { echo "crosscheck-decide: $FILE is not valid JSON" >&2; exit 2; }

REASONS="$(jq -r '
  def effective_attribution:
    if (.attribution_checked // null) as $c
       | ($c != null and $c != "inconclusive")
    then .attribution_checked
    else .attribution
    end;

  ( [ .claims_verified[]? | select(.result == "refuted") | "refuted claim: " + .claim_id ] )
  + ( [ .uncovered_scope[]? | "uncovered scope: " + .repo + " — " + .what_changed ] )
  + ( [ .findings[]?
        | select(.severity == "blocker" or .severity == "major")
        | select((. | effective_attribution) == "introduced-by-change")
        | "open " + .severity + " introduced by this change: " + .id + " — " + .what_is_wrong ] )
  | .[]' "$FILE")"

DECISION="stop"
[[ -n "$REASONS" ]] && DECISION="continue"

if [[ "$DECISION" == "continue" && -n "$ROUND" ]]; then
  if [[ "$ROUND" =~ ^[0-9]+$ && "$MAX_ROUNDS" =~ ^[0-9]+$ ]] && (( ROUND >= MAX_ROUNDS )); then
    DECISION="halt"
  fi
fi

echo "$DECISION"

if (( EXPLAIN )); then
  {
    if [[ -z "$REASONS" ]]; then
      echo "  no refuted claim, no uncovered scope, no open blocker/major introduced by this change"
    else
      while IFS= read -r r; do echo "  $r"; done <<<"$REASONS"
    fi
    # Name every attribution the machine did not settle, so a decision that
    # rests on the reviewer's word says so out loud.
    jq -r '
      .findings[]?
      | select(.severity == "blocker" or .severity == "major")
      | select(((.attribution_checked // null) == null) or (.attribution_checked == "inconclusive"))
      | "  attribution unverified (reviewer assertion stands): " + .id + " = " + .attribution' "$FILE"
    [[ "$DECISION" == "halt" ]] && echo "  round cap reached ($ROUND/$MAX_ROUNDS) — surface to the operator"
  } >&2
fi

case "$DECISION" in
  stop)     exit 0  ;;
  continue) exit 10 ;;
  halt)     exit 11 ;;
esac
