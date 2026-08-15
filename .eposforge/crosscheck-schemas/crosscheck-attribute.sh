#!/usr/bin/env bash
# crosscheck-attribute.sh — settle "was this already broken?" by execution, not assertion.
#
#   crosscheck-attribute.sh --repo <path> --base <sha> --head <sha> --cmd '<repro>'
#   crosscheck-attribute.sh --findings <file> --handoff <file> [--write]
#
# "Pre-existing" is the most abused finding category and the one that decides
# whether the loop continues, so it is the one worth taking out of both agents'
# hands. The reviewer's repro_cmd is run at base_sha and again at head_sha in
# detached worktrees; the two exit codes settle it.
#
# Convention: the repro command EXITS 0 WHEN THE DEFECT IS PRESENT.
#
#   base: absent · head: present  -> introduced-by-change
#   base: present · head: present -> pre-existing
#   head: absent                  -> not-a-defect
#   worktree or command could not run -> inconclusive
#
# `inconclusive` is a real answer, not a failure to have one: it says the machine
# did not settle this and the reviewer's assertion is still standing. The stop
# rule reads it that way, and --explain says so out loud.
#
# In --findings mode every blocker/major finding with a repro_cmd is attributed
# and, with --write, the answer is stored as `attribution_checked` — leaving the
# reviewer's own `attribution` beside it, so a disagreement stays visible.
#
# ── repro_cmd is foreign code. It does not run by default. ───────────────────
# `evidence_cmd` is written by the author, so running it grants nothing that was
# not already granted. `repro_cmd` is the opposite: it arrives inside
# findings.json, written by a *different vendor's model*, and this script would
# otherwise hand it a shell on the host with the operator's ambient credentials.
# That is the only inbound execution path in the whole contract, and it is not
# what clearance-on-transport protects against.
#
# So --findings mode REFUSES to execute unless the operator says otherwise, with
# --allow-reviewer-exec or CROSSCHECK_ALLOW_REVIEWER_EXEC=1. Every command is
# printed before it runs, so approving is done with the text in view.
#
# --repo/--cmd is not gated: that command came from whoever typed the command
# line, which is the same trust as typing it into a shell. Piping a payload's
# repro_cmd into --cmd defeats the gate, and is a deliberate act.
#
# Prints one word per attribution on stdout.
# Exit: 0 ok · 3 inconclusive (single-finding mode) · 4 execution refused
#       · 2 usage / IO.
set -uo pipefail

TIMEOUT="${CROSSCHECK_CMD_TIMEOUT:-120}"
ALLOW_EXEC="${CROSSCHECK_ALLOW_REVIEWER_EXEC:-0}"
REPO=""; BASE=""; HEAD=""; CMD=""; FINDINGS=""; HANDOFF=""; WRITE=0
usage() { sed -n '2,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "crosscheck-attribute: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --base)     BASE="$2"; shift 2 ;;
    --head)     HEAD="$2"; shift 2 ;;
    --cmd)      CMD="$2"; shift 2 ;;
    --findings) FINDINGS="$2"; shift 2 ;;
    --handoff)  HANDOFF="$2"; shift 2 ;;
    --write)    WRITE=1; shift ;;
    --allow-reviewer-exec) ALLOW_EXEC=1; shift ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git not found"
command -v jq  >/dev/null 2>&1 || die "jq not found"

# Worktrees are registered in the repo, so an interrupted probe leaves one
# behind in somebody's working repository. Track and clean unconditionally.
ACTIVE_WT=""
ACTIVE_REPO=""
cleanup_worktree() {
  [[ -n "$ACTIVE_WT" ]] || return 0
  [[ -n "$ACTIVE_REPO" ]] && git -C "$ACTIVE_REPO" worktree remove --force "$ACTIVE_WT" >/dev/null 2>&1
  rm -rf "$ACTIVE_WT"
  [[ -n "$ACTIVE_REPO" ]] && git -C "$ACTIVE_REPO" worktree prune >/dev/null 2>&1
  ACTIVE_WT=""; ACTIVE_REPO=""
}
trap 'cleanup_worktree' EXIT INT TERM HUP

# Run $2 at revision $3 in a detached worktree of repo $1.
# Echoes "present" | "absent" | "error".
probe_at() {
  local repo="$1" cmd="$2" rev="$3"
  local wt rc
  wt="$(mktemp -d)" || { echo error; return; }
  if ! git -C "$repo" worktree add --detach --quiet "$wt" "$rev" >/dev/null 2>&1; then
    rm -rf "$wt"; echo error; return
  fi
  ACTIVE_WT="$wt"; ACTIVE_REPO="$repo"
  # Bounded: a repro that never returns would otherwise hang the whole loop,
  # and a timeout is not evidence of anything, so it reports error.
  timeout --kill-after=10s "$TIMEOUT" bash -c "cd '$wt' && $cmd" >/dev/null 2>&1
  rc=$?
  cleanup_worktree
  if   [[ $rc -eq 0 ]]; then echo present
  elif [[ $rc -eq 124 || $rc -eq 137 ]]; then echo error   # timed out
  elif [[ $rc -gt 125 ]]; then echo error                  # 126/127 not executable / not found
  else echo absent; fi
}

attribute() {
  local repo="$1" base="$2" head="$3" cmd="$4"
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo inconclusive; return; }
  local at_head at_base
  at_head="$(probe_at "$repo" "$cmd" "$head")"
  [[ "$at_head" == "error" ]] && { echo inconclusive; return; }
  if [[ "$at_head" == "absent" ]]; then echo not-a-defect; return; fi
  at_base="$(probe_at "$repo" "$cmd" "$base")"
  case "$at_base" in
    error)   echo inconclusive ;;
    present) echo pre-existing ;;
    absent)  echo introduced-by-change ;;
  esac
}

# ── single finding ───────────────────────────────────────────────────────────
if [[ -z "$FINDINGS" ]]; then
  [[ -n "$REPO" && -n "$BASE" && -n "$HEAD" && -n "$CMD" ]] \
    || die "need --repo, --base, --head and --cmd (or --findings)"
  r="$(attribute "$REPO" "$BASE" "$HEAD" "$CMD")"
  echo "$r"
  [[ "$r" == "inconclusive" ]] && exit 3
  exit 0
fi

# ── whole findings payload ───────────────────────────────────────────────────
[[ -r "$FINDINGS" ]] || die "cannot read $FINDINGS"
[[ -n "$HANDOFF" && -r "$HANDOFF" ]] || die "--findings needs --handoff (for the scope SHAs)"

# Show the operator exactly what a foreign model is asking to run, then refuse
# unless they have said yes. Listing first, so --allow-reviewer-exec is given
# with the commands already in view rather than sight-unseen.
PENDING="$(jq -r '
  .findings[]
  | select(.severity == "blocker" or .severity == "major")
  | select((.repro_cmd // "") != "")
  | "  \(.id)  [\(.repo)]  \(.repro_cmd)"' "$FINDINGS")"

if [[ -n "$PENDING" ]]; then
  {
    echo "crosscheck-attribute: these commands came from the REVIEWER's payload, not from you:"
    echo "$PENDING"
  } >&2
fi

if [[ "$ALLOW_EXEC" != "1" ]]; then
  if [[ -z "$PENDING" ]]; then
    echo "crosscheck-attribute: nothing to attribute (no blocker/major finding carries a repro_cmd)" >&2
    exit 0
  fi
  {
    echo
    echo "REFUSED: running them would give a different vendor's model a shell on this host,"
    echo "in a worktree of your repository, with your ambient credentials."
    echo "Re-run with --allow-reviewer-exec (or CROSSCHECK_ALLOW_REVIEWER_EXEC=1) to proceed."
    echo "Without it, attribution stays the reviewer's assertion and the stop rule treats"
    echo "it as unverified rather than settled."
  } >&2
  exit 4
fi

RESULTS="$(mktemp)" || die "cannot create temp file"
trap 'rm -f "$RESULTS" "$RESULTS.tmp"' EXIT
echo '{}' > "$RESULTS"

while IFS=$'\t' read -r fid frepo fcmd; do
  [[ -n "$fid" ]] || continue
  # Resolve the finding's repo against the handoff scope: exact repo_path, then
  # basename. A finding naming a repo the handoff never declared is not
  # attributable, and saying so is better than guessing which one it meant.
  read -r path base head < <(jq -r --arg r "$frepo" '
    (.scope[] | select(.repo_path == $r))
    // (.scope[] | select((.repo_path | split("/") | last) == $r))
    // empty
    | [.repo_path, .base_sha, .head_sha] | @tsv' "$HANDOFF" | head -1)

  if [[ -z "${path:-}" ]]; then
    verdict="inconclusive"
  else
    verdict="$(attribute "$path" "$base" "$head" "$fcmd")"
  fi
  asserted="$(jq -r --arg id "$fid" '.findings[] | select(.id == $id) | .attribution' "$FINDINGS")"
  if [[ "$verdict" != "inconclusive" && "$verdict" != "$asserted" ]]; then
    printf '%-6s %s   (reviewer asserted %s — the machine check wins)\n' "$fid" "$verdict" "$asserted"
  else
    printf '%-6s %s\n' "$fid" "$verdict"
  fi
  jq --arg id "$fid" --arg v "$verdict" '.[$id] = $v' "$RESULTS" > "$RESULTS.tmp" \
    && mv "$RESULTS.tmp" "$RESULTS"
done < <(jq -r '
  .findings[]
  | select(.severity == "blocker" or .severity == "major")
  | select((.repro_cmd // "") != "")
  | [ .id, .repo, .repro_cmd ] | @tsv' "$FINDINGS")

if (( WRITE )); then
  jq --slurpfile r "$RESULTS" '
    .findings |= map(
      . as $f
      | if ($r[0] | has($f.id)) then .attribution_checked = $r[0][$f.id] else . end
    )' "$FINDINGS" > "$FINDINGS.tmp" && mv "$FINDINGS.tmp" "$FINDINGS" \
    || die "failed to write attribution_checked into $FINDINGS"
fi
exit 0
