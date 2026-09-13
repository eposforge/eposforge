#!/usr/bin/env bash
# crosscheck-verify-scope.sh — do the revisions this payload names still exist?
#
#   crosscheck-verify-scope.sh --handoff <file> [--write] [--quiet]
#
# A handoff is a promise that the reviewer can read a specific tree. That promise
# expires, and not only when someone rewrites history deliberately: an ordinary
# `git pull` on a branch with unpushed commits rebases them, and the replacement
# carries a byte-identical commit subject. Nothing a human reads says the
# revision moved. Only this check notices.
#
# Per scope entry:
#
#   ok               base and head both resolve, and head is still an ancestor
#                    of the repository's current tip
#   head-orphaned    head still exists as an object but is no longer reachable
#                    from the branch — the usual signature of a rebase. It is
#                    readable HERE, from the reflog, and nowhere else: not after
#                    gc, and not on the machine a reviewer might run on
#   head-missing     head does not resolve to a commit at all
#   base-missing     base does not resolve — coverage and attribution both need
#                    it, and a shallow clone is the common cause
#   repo-unreachable the path is not a git repository from here
#
# --write stamps `integrity` and `verified_at` onto each scope entry.
# `validate-payload.sh --final` REQUIRES integrity == "ok" everywhere, so a
# payload cannot be finalised without this having run. That is the point: the
# check has to sit at transport, because the drift happens after authoring.
#
# Re-verify, do not refresh. Advancing head_sha to whatever HEAD says now would
# make the payload valid again while losing the one fact that matters — that the
# tree the claims were written against is not the tree being handed over.
#
# Exit: 0 every entry ok · 10 at least one entry drifted · 2 usage / IO.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

HANDOFF=""; WRITE=0; QUIET=0
usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "crosscheck-verify-scope: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --handoff) HANDOFF="$2"; shift 2 ;;
    --write)   WRITE=1; shift ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$HANDOFF" ]] || usage
command -v jq  >/dev/null 2>&1 || die "jq not found"
command -v git >/dev/null 2>&1 || die "git not found"
[[ -r "$HANDOFF" ]] || die "cannot read $HANDOFF"

RESULTS="$(mktemp)" || die "cannot create temp file"
DIRTY="$(mktemp)" || die "cannot create temp file"
trap 'rm -f "$RESULTS" "$RESULTS.tmp" "$DIRTY" "$DIRTY.tmp"' EXIT
echo '{}' > "$RESULTS"
echo '{}' > "$DIRTY"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DRIFT=0

verify_one() {
  local repo="$1" base="$2" head="$3"
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo repo-unreachable; return; }
  git -C "$repo" rev-parse --verify --quiet "$head^{commit}" >/dev/null 2>&1 || { echo head-missing; return; }
  # Reachability, not existence. The reflog keeps an orphan alive locally long
  # after it stopped describing the branch, which is exactly how this hides.
  if ! git -C "$repo" merge-base --is-ancestor "$head" HEAD 2>/dev/null; then
    echo head-orphaned; return
  fi
  git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo base-missing; return; }
  echo ok
}

while IFS=$'\t' read -r repo base head was_dirty; do
  [[ -n "$repo" ]] || continue
  verdict="$(verify_one "$repo" "$base" "$head")"
  [[ "$verdict" == "ok" ]] || DRIFT=1

  # `dirty` is not a promise, it is a fact about the tree right now — and the
  # one fact that decides whether coverage sees anything at all. It is stamped
  # when the handoff is opened, which for a session-start trigger is BEFORE any
  # work exists: left alone it says false, coverage compares base..head over an
  # empty range, and reports uncovered=0 for a change it never looked at. That
  # zero is vacuous, so re-read it here rather than believing the payload.
  now_dirty=false
  if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then now_dirty=true; fi
  jq --arg r "$repo" --argjson v "$now_dirty" '.[$r] = $v' "$DIRTY" > "$DIRTY.tmp" \
    && mv "$DIRTY.tmp" "$DIRTY"
  if (( ! QUIET )) && [[ "$now_dirty" != "$was_dirty" ]]; then
    printf '%-12s %s\n' "dirty=$now_dirty" "$repo (payload said $was_dirty)"
  fi

  if (( ! QUIET )); then
    printf '%-12s %s\n' "$verdict" "$repo"
    case "$verdict" in
      head-orphaned)
        # Name the replacement when there is an obvious one. An identical subject
        # line on a different sha is the whole reason this goes unnoticed.
        subj="$(git -C "$repo" log -1 --format=%s "$head" 2>/dev/null | tail -1)"
        repl="$(git -C "$repo" log --format='%H %s' HEAD 2>/dev/null \
                | grep -F -m1 -- "$subj" | cut -d' ' -f1)"
        echo "             handoff names $head, which is no longer on this branch"
        [[ -n "$subj" ]] && echo "             subject: $subj"
        if [[ -n "$repl" ]]; then
          echo "             a commit with the SAME subject is on the branch as ${repl:0:40}"
          echo "             re-verify what changed; do NOT just adopt it"
        fi
        ;;
      head-missing)
        echo "             $head does not resolve here — a fresh clone or a gc would see nothing" ;;
      base-missing)
        echo "             $base does not resolve; coverage and attribution both need it$( [[ -f "$(git -C "$repo" rev-parse --git-dir 2>/dev/null)/shallow" ]] && echo " (SHALLOW clone)" )" ;;
      repo-unreachable)
        echo "             not a git repository from here" ;;
    esac
  fi

  jq --arg r "$repo" --arg v "$verdict" '.[$r] = $v' "$RESULTS" > "$RESULTS.tmp" \
    && mv "$RESULTS.tmp" "$RESULTS"
done < <(jq -r '.scope[] | [.repo_path, .base_sha, .head_sha, (.dirty | tostring)] | @tsv' "$HANDOFF")

if (( WRITE )); then
  jq --slurpfile r "$RESULTS" --slurpfile d "$DIRTY" --arg now "$NOW" '
    .scope |= map(. as $s
      | .integrity = ($r[0][$s.repo_path] // "repo-unreachable")
      | .dirty = (if ($d[0] | has($s.repo_path)) then $d[0][$s.repo_path] else .dirty end)
      | .verified_at = $now)' "$HANDOFF" > "$HANDOFF.vs.tmp" \
    && mv "$HANDOFF.vs.tmp" "$HANDOFF" \
    || die "failed to write integrity into $HANDOFF"
fi

if (( DRIFT )); then
  (( QUIET )) || {
    echo
    echo "SCOPE DRIFT: the reviewer cannot be handed what this payload promises." >&2
    echo "Re-verify what actually changed and re-open the round. Do not advance" >&2
    echo "head_sha to the current tip — that makes the payload valid again while" >&2
    echo "losing the fact that the claims were written against a different tree." >&2
  }
  exit 10
fi
exit 0
