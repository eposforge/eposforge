#!/usr/bin/env bash
# crosscheck-next-round.sh — open round N+1 from a disposed round N.
#
#   crosscheck-next-round.sh [--handoff FILE | --session S --round N]
#                            [--dir ROOT] [--force]
#
# A loop needs a way to start the next round that is not "write the JSON by
# hand". `crosscheck-claim open` cannot do it: it mints round 1 of a fresh
# session, with no findings behind it and `disposition_ref: null`, which
# `validate-payload.sh --final` correctly refuses for any round above 1.
#
# What this carries forward, and what it deliberately does not:
#
#   carried   session and implementer identity; the scope repositories, with
#             each `base_sha` advanced to that round's `head_sha`; the ground
#             rules; `disposition_ref` pointing at the answers just given.
#   dropped   claims, traps, attacks, flags, headline numbers, artifacts.
#
# The dropped half is the point. Round N+1 is a delta — what changed in
# response to the findings — not a restatement of round N with the fixes
# appended. A payload that re-asserts everything grows every round, costs more
# every round, and buries the two lines that are actually new. Advancing
# `base_sha` to the previous head is the same discipline expressed as
# arithmetic: coverage then measures the fixes, not the original work.
#
# It refuses to open a round the loop has no business opening:
#
#   - findings that were never answered. Every finding needs a disposition
#     before the next round, or "the two agents agree" is unreachable: the
#     reviewer restates, the implementer restates, and nothing converges.
#   - a loop the stop rule already ended. `--force` overrides, and says so.
#
# Exit: 0 opened · 1 refused · 2 usage / IO.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-payload.sh"
DECIDE="$SCRIPT_DIR/crosscheck-decide.sh"
# shellcheck source=lib/budget.sh
. "$SCRIPT_DIR/lib/budget.sh"

ROOT="${CROSSCHECK_DIR:-$HOME/.crosscheck}"
CAP="${CROSSCHECK_HANDOFF_TOKEN_CAP:-8000}"
SESSION="${CROSSCHECK_SESSION:-}"
ROUND="${CROSSCHECK_ROUND:-}"
HANDOFF=""
FORCE=0

usage() { sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die()   { echo "crosscheck-next-round: $*" >&2; exit 2; }
no()    { echo "crosscheck-next-round: refused — $*" >&2; exit 1; }
say()   { printf '%s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --handoff) HANDOFF="$2"; shift 2 ;;
    --session) SESSION="$2"; shift 2 ;;
    --round)   ROUND="$2"; shift 2 ;;
    --dir)     ROOT="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found"

if [[ -z "$HANDOFF" ]]; then
  [[ -n "$SESSION" ]] || SESSION="$(cat "$ROOT/current" 2>/dev/null)"
  [[ -n "$SESSION" ]] || die "no session: pass --handoff, --session, or set CROSSCHECK_SESSION"
  [[ -n "$ROUND" ]]   || ROUND=1
  HANDOFF="$ROOT/$SESSION/round-$ROUND/handoff.json"
fi
[[ -r "$HANDOFF" ]] || die "cannot read $HANDOFF"

DIR="$(cd "$(dirname "$HANDOFF")" && pwd -P)"
HANDOFF="$DIR/$(basename "$HANDOFF")"
ROUND="$(jq -r '.round' "$HANDOFF")"
[[ "$ROUND" =~ ^[0-9]+$ ]] || die "$HANDOFF has no usable round"
NEXT=$((ROUND + 1))
SESSION="$(jq -r '.session' "$HANDOFF")"

FINDINGS="$DIR/findings.json"
DISPOSITION="$DIR/disposition.json"
NEXT_DIR="$(dirname "$DIR")/round-$NEXT"
NEXT_HANDOFF="$NEXT_DIR/handoff.json"

[[ -e "$NEXT_HANDOFF" ]] && no "round $NEXT already exists at $NEXT_HANDOFF"

# ── the previous round must actually be finished ─────────────────────────────
[[ -r "$FINDINGS" ]] \
  || no "round $ROUND has no findings at $FINDINGS — there is nothing to answer yet, so there is no next round to open"
[[ -r "$DISPOSITION" ]] \
  || no "round $ROUND has no disposition at $DISPOSITION — every finding needs an answer (accepted-fixed / accepted-deferred / rejected) before the next round. Without that leg the next round re-asserts instead of answering."

# Presence is not enough: a disposition that skips a finding leaves it
# unanswered while looking like an answer, and the next round would carry a
# `disposition_ref` to a file that does not do the job it is referenced for.
if ! "$VALIDATE" disposition "$DISPOSITION" --findings "$FINDINGS" >&2; then
  no "the disposition at $DISPOSITION does not answer round $ROUND's findings"
fi

# ── and the loop must not already be over ────────────────────────────────────
DECISION="$("$DECIDE" "$FINDINGS" --round "$ROUND" 2>/dev/null | tail -1)"
if [[ "$DECISION" == "stop" ]] && (( ! FORCE )); then
  no "the stop rule already ended this loop at round $ROUND (decision: stop). Another round would be work nothing asked for; pass --force if you mean it anyway."
fi
if [[ "$DECISION" == "stop" ]]; then
  say "crosscheck-next-round: --force: opening round $NEXT although the stop rule said stop at round $ROUND"
fi

# ── carry the scope forward, advancing each base to that round's head ────────
# head_sha is re-read rather than copied: the tree has moved since round N was
# transported — that movement is the fixes — and the new payload has to be about
# the tree as it is now. base_sha is NOT re-read: it is round N's head, which is
# what makes round N+1 a delta.
SCOPE="$(jq -c '.scope' "$HANDOFF")"
NEW_SCOPE='[]'
while read -r entry; do
  [[ -n "$entry" ]] || continue
  repo="$(jq -r '.repo_path' <<<"$entry")"
  base="$(jq -r '.head_sha' <<<"$entry")"
  head="$base"; dirty=false
  if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    h="$(git -C "$repo" rev-parse HEAD 2>/dev/null)" && [[ -n "$h" ]] && head="$h"
    [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]] && dirty=true
  else
    say "crosscheck-next-round: warning — $repo is not readable as a git repository now; carrying its revisions forward unchanged"
  fi
  NEW_SCOPE="$(jq -c --argjson e "$entry" --arg b "$base" --arg h "$head" --argjson d "$dirty" \
                  --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
                  . + [$e + {base_sha:$b, head_sha:$h, dirty:$d, integrity:"ok", verified_at:$t}]' \
               <<<"$NEW_SCOPE")" || die "cannot build the new scope"
done < <(jq -c '.[]' <<<"$SCOPE")

mkdir -p "$NEXT_DIR" || die "cannot create $NEXT_DIR"

jq -n --argjson r "$NEXT" --arg s "$SESSION" \
      --argjson impl "$(jq -c '.implementer' "$HANDOFF")" \
      --argjson scope "$NEW_SCOPE" \
      --arg clr "$(jq -r '.clearance_required' "$HANDOFF")" \
      --argjson rules "$(jq -c '.ground_rules' "$HANDOFF")" \
      --arg dref "$DISPOSITION" '
  {
    schema: "eposforge.crosscheck.handoff/1",
    round: $r,
    session: $s,
    implementer: $impl,
    scope: $scope,
    clearance_required: $clr,
    claims: [],
    headline_numbers: {},
    traps: [],
    attack_first: [],
    self_flagged: [],
    out_of_scope: [],
    artifacts: [],
    ground_rules: $rules,
    disposition_ref: $dref,
    budget: {est_tokens: 0, rendered_bytes: 0, cap: 0, over_budget: false}
  }' > "$NEXT_HANDOFF.tmp" || die "cannot write $NEXT_HANDOFF"
mv "$NEXT_HANDOFF.tmp" "$NEXT_HANDOFF" || die "cannot write $NEXT_HANDOFF"
refresh_budget "$NEXT_HANDOFF" "$CAP"

if ! "$VALIDATE" handoff "$NEXT_HANDOFF" >&2; then
  die "the round-$NEXT payload this built does not validate — that is a defect here, not in the caller"
fi

say "→ round $NEXT open at $NEXT_HANDOFF"
say "  answers round $ROUND: $DISPOSITION"
say "  claims start empty on purpose: record what you changed in response to the findings, not what you did in round $ROUND."
printf '%s\n' "$NEXT_HANDOFF"
