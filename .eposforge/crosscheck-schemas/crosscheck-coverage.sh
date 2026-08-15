#!/usr/bin/env bash
# crosscheck-coverage.sh — changed files minus claimed files. Set arithmetic, no LLM.
#
#   crosscheck-coverage.sh --handoff <file> [--write] [--strict]
#   crosscheck-coverage.sh --handoff <file> --changed <file>     # offline / fixtures
#
# Coverage stops being something a reviewer might notice and becomes something
# that is computed before the reviewer is spawned. That matters because an
# implementer who knows the rubric can otherwise offer only narrow, trivially
# checkable claims: the gap is what makes that strategy visible. Whether a given
# uncovered file MATTERS is still the reviewer's judgment — but it gets to make
# that judgment against a list, not against its own attention.
#
#   --write    store the result in the handoff's `coverage` object
#   --strict   exit 10 when anything is uncovered (for use as a gate)
#   --changed  read the changed-file list from a file instead of git, one
#              "<repo_path>\t<repo-relative path>" per line. For fixtures and for
#              repos that are not reachable from where this runs.
#
# Changed files come from `git diff --name-only base..head` per scope entry, plus
# the working tree when that entry is marked dirty — a dirty tree is part of what
# the reviewer is being asked about and head_sha does not describe it.
#
# Exit: 0 ok · 10 uncovered files exist (--strict only) · 2 usage / IO.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/budget.sh
. "$SCRIPT_DIR/lib/budget.sh"

HANDOFF=""; CHANGED_FILE=""; WRITE=0; STRICT=0
usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "crosscheck-coverage: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --handoff) HANDOFF="$2"; shift 2 ;;
    --changed) CHANGED_FILE="$2"; shift 2 ;;
    --write)   WRITE=1; shift ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$HANDOFF" ]] || usage
command -v jq >/dev/null 2>&1 || die "jq not found"
[[ -r "$HANDOFF" ]] || die "cannot read $HANDOFF"

TMP="$(mktemp -d)" || die "cannot create temp dir"
trap 'rm -rf "$TMP"' EXIT

CHANGED="$TMP/changed"
: > "$CHANGED"

if [[ -n "$CHANGED_FILE" ]]; then
  [[ -r "$CHANGED_FILE" ]] || die "cannot read $CHANGED_FILE"
  grep -v '^[[:space:]]*$' "$CHANGED_FILE" > "$CHANGED" || true
else
  while IFS=$'\t' read -r repo base head dirty; do
    [[ -n "$repo" ]] || continue
    git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 \
      || die "$repo is not a reachable git repository (use --changed for an offline list)"
    # A shallow clone has no parent for its earliest commit, so base..head
    # silently degrades into "the entire tree changed". Refuse instead: a
    # coverage report nobody can trust is worse than no coverage report.
    for rev in "$base" "$head"; do
      git -C "$repo" rev-parse --verify --quiet "$rev^{commit}" >/dev/null 2>&1 || die \
        "$repo: '$rev' is not a commit in this clone$( [[ -f "$(git -C "$repo" rev-parse --git-dir)/shallow" ]] && echo " (it is a SHALLOW clone — deepen it with 'git fetch --unshallow' or name a reachable base)" ) — refusing to report coverage rather than reporting the whole tree"
    done
    git -C "$repo" diff --name-only "$base".."$head" 2>/dev/null \
      | while IFS= read -r f; do printf '%s\t%s\n' "$repo" "$f"; done >> "$CHANGED"
    if [[ "$dirty" == "true" ]]; then
      # Uncommitted work is in scope for the review even though no SHA names it.
      # -z so a rename is two paths, not the single token "old -> new".
      # -uall so an untracked directory lists its files, not "dirname/".
      # Rename/copy records are XY<space>NEW\0OLD\0; everything else is one field.
      while IFS= read -r -d '' rec; do
        [[ -n "$rec" ]] || continue
        xy="${rec:0:2}"
        path="${rec:3}"
        [[ -n "$path" ]] && printf '%s\t%s\n' "$repo" "$path"
        case "$xy" in
          *R*|*C*)
            if IFS= read -r -d '' orig; then
              [[ -n "$orig" ]] && printf '%s\t%s\n' "$repo" "$orig"
            fi
            ;;
        esac
      done < <(git -C "$repo" status --porcelain -z -uall 2>/dev/null) >> "$CHANGED"
    fi
  done < <(jq -r '.scope[] | [.repo_path, .base_sha, .head_sha, (.dirty|tostring)] | @tsv' "$HANDOFF")
fi

sort -u "$CHANGED" -o "$CHANGED"

# A claim covers a changed file if its files[] names the repo-relative path or
# the absolute path. Nothing fuzzier: a coverage rule that guesses would let a
# claim about one file silently absorb another.
UNCOVERED="$(jq -R -s --slurpfile h "$HANDOFF" '
  . as $raw
  | (($h[0].claims // []) | map(.files // []) | add // [] | map(select(length > 0))) as $claimed
  | $raw
  | split("\n") | map(select(length > 0)) | map(split("\t"))
  | map(select(length == 2))
  | map({repo: .[0], file: .[1]})
  | map(select(
      ([ .file, (.repo + "/" + .file) ] | any(. as $p | ($claimed | index($p)) != null)) | not
    ))
  | map(.repo + "/" + .file)
  | unique
' "$CHANGED")"

CHANGED_N="$(wc -l <"$CHANGED" | tr -d ' ')"
CLAIMED_N="$(jq -r '[.claims[].files[]?] | unique | length' "$HANDOFF")"
UNCOVERED_N="$(printf '%s' "$UNCOVERED" | jq -r 'length')"

if (( WRITE )); then
  jq --argjson c "$CHANGED_N" --argjson m "$CLAIMED_N" --argjson u "$UNCOVERED" \
     '.coverage = {changed_files: $c, claimed_files: $m, uncovered: $u}' \
     "$HANDOFF" > "$TMP/out.json" && mv "$TMP/out.json" "$HANDOFF" \
     || die "failed to write coverage into $HANDOFF"
  # A long uncovered list is itself a large payload, so the budget it was
  # written under no longer describes it.
  refresh_budget "$HANDOFF" "$(jq -r '.budget.cap // 8000' "$HANDOFF")" \
    || die "failed to refresh the budget in $HANDOFF"
fi

echo "changed=$CHANGED_N claimed=$CLAIMED_N uncovered=$UNCOVERED_N"
printf '%s' "$UNCOVERED" | jq -r '.[]'

if (( STRICT )) && (( UNCOVERED_N > 0 )); then exit 10; fi
exit 0
