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
# Prints one word per attribution on stdout.
# Exit: 0 ok · 3 inconclusive (single-finding mode) · 2 usage / IO.
set -uo pipefail

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
    -h|--help)  usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git not found"
command -v jq  >/dev/null 2>&1 || die "jq not found"

# Run $2 at revision $3 in a detached worktree of repo $1.
# Echoes "present" | "absent" | "error".
probe_at() {
  local repo="$1" cmd="$2" rev="$3"
  local wt rc
  wt="$(mktemp -d)" || { echo error; return; }
  if ! git -C "$repo" worktree add --detach --quiet "$wt" "$rev" >/dev/null 2>&1; then
    rm -rf "$wt"; echo error; return
  fi
  ( cd "$wt" && bash -c "$cmd" ) >/dev/null 2>&1
  rc=$?
  git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  if [[ $rc -eq 0 ]]; then echo present
  elif [[ $rc -gt 125 ]]; then echo error      # 126/127 = not executable / not found
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
