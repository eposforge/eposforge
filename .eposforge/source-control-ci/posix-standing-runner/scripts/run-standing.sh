#!/usr/bin/env bash
# run-standing.sh — POSIX standing-suite dispatcher.
#
# Worked reference for the Source Control + CI test-runner sub-contract.
# Example, not a mandate: adopters may pick any runner that satisfies the
# contract. This one is language-agnostic so agent-config, platform, and
# product trees can share one command.
#
# Usage:
#   run-standing.sh [--held-out DIR] [REPO ...]
#   run-standing.sh --list [--repo REPO]
#   run-standing.sh --accepts CMD [--repo REPO]
#   run-standing.sh --check-gate [--repo REPO] [--base SHA]
#
# With no REPO args, uses the git root of cwd (or cwd if not a git work tree).
# Each REPO must contain .eposforge/standing-suite:
#   * executable → run it with cwd=REPO
#   * otherwise  → each non-empty, non-# line is a repo-relative command
#
# Exit: 0 ok · 1 standing check failed / command not accepted / gate mixed · 2 usage
set -euo pipefail

SUITE_REL=".eposforge/standing-suite"
GATE_PATHS=(
  ".eposforge/standing-suite"
  ".eposforge/source-control-ci/posix-standing-runner/"
)

usage() {
  sed -n '9,15p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

die() { echo "run-standing: $*" >&2; exit 2; }
fail() { echo "run-standing: $*" >&2; exit 1; }

MODE="run"
HELD_OUT=""
ACCEPTS_CMD=""
BASE_SHA=""
REPO_FLAG=""
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --held-out) HELD_OUT="${2:?}"; shift 2 ;;
    --list) MODE="list"; shift ;;
    --accepts) MODE="accepts"; ACCEPTS_CMD="${2:?}"; shift 2 ;;
    --check-gate) MODE="gate"; shift ;;
    --repo) REPO_FLAG="${2:?}"; shift 2 ;;
    --base) BASE_SHA="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; REPOS+=("$@"); break ;;
    -*) die "unknown arg: $1" ;;
    *) REPOS+=("$1"); shift ;;
  esac
done

repo_root() {
  local d="$1"
  [[ -d "$d" ]] || die "not a directory: $d"
  d="$(cd "$d" && pwd -P)"
  # A nested tree with its own standing-suite (a constructed product fixture
  # inside another git work tree) MUST stay that tree. Walking up to the parent
  # git root re-invokes the parent's suite and recurses.
  if [[ -e "$d/$SUITE_REL" ]]; then
    printf '%s\n' "$d"
    return
  fi
  local g
  g="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$g" ]]; then
    printf '%s\n' "$g"
  else
    printf '%s\n' "$d"
  fi
}

default_repo() {
  if [[ -n "$REPO_FLAG" ]]; then
    repo_root "$REPO_FLAG"
    return
  fi
  repo_root "."
}

# First token of a command, stripped of a leading ./
cmd_token() {
  local cmd="$1" tok
  tok="$(awk '{print $1; exit}' <<<"$cmd")"
  tok="${tok#./}"
  printf '%s\n' "$tok"
}

# True if CMD is a repo-local standing check in REPO.
standing_accepts() {
  local repo="$1" cmd="$2"
  local suite="$repo/$SUITE_REL"
  [[ -e "$suite" ]] || return 1
  local tok
  tok="$(cmd_token "$cmd")"
  case "$tok" in
    ""|/*|*..*|~*) return 1 ;;
  esac
  if [[ "$tok" == "$SUITE_REL" ]]; then
    [[ -e "$suite" ]] && return 0
    return 1
  fi
  # Must be a runnable file under the repo (repo-local script), not a PATH binary.
  [[ -f "$repo/$tok" && -x "$repo/$tok" ]] || return 1
  local resolved suite_resolved
  resolved="$(cd "$repo" && realpath -m "$tok")"
  suite_resolved="$(cd "$repo" && realpath -m .)"
  [[ "$resolved" == "$suite_resolved"/* ]] || return 1
  if [[ -x "$suite" && ! -d "$suite" ]]; then
    # Executable suite: only the suite itself is the standing command.
    return 1
  fi
  # Listed in the suite file.
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#./}"
    [[ "$line" == "$tok" ]] && return 0
  done < "$suite"
  return 1
}

list_entries() {
  local repo="$1"
  local suite="$repo/$SUITE_REL"
  [[ -e "$suite" ]] || fail "no $SUITE_REL in $repo"
  echo "$SUITE_REL"
  if [[ -x "$suite" && ! -d "$suite" ]]; then
    return 0
  fi
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "${line#./}"
  done < "$suite"
}

run_one_cmd() {
  local repo="$1" cmd="$2"
  ( cd "$repo" && bash -c "$cmd" )
}

run_repo() {
  local repo="$1"
  local suite="$repo/$SUITE_REL"
  [[ -e "$suite" ]] || fail "no $SUITE_REL in $repo"
  if [[ -x "$suite" && ! -d "$suite" ]]; then
    echo "run-standing: $repo: $SUITE_REL"
    ( cd "$repo" && ./"$SUITE_REL" )
    return
  fi
  local line any=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    any=1
    echo "run-standing: $repo: $line"
    run_one_cmd "$repo" "$line"
  done < "$suite"
  (( any )) || fail "empty standing-suite in $repo"
}

run_held_out() {
  local dir="$1"
  [[ -d "$dir" ]] || fail "held-out dir not found: $dir"
  local f any=0
  # Hidden extra checks: every executable or *.sh in the dir.
  while IFS= read -r -d '' f; do
    any=1
    echo "run-standing: held-out: $f"
    bash "$f"
  done < <(find "$dir" -maxdepth 1 \( -type f -executable -o -name '*.sh' \) -print0 | sort -z)
  (( any )) || fail "held-out dir has no checks: $dir"
}

is_gate_path() {
  local rel="$1" g
  for g in "${GATE_PATHS[@]}"; do
    [[ "$rel" == "$g" || "$rel" == "$g"* ]] && return 0
  done
  return 1
}

check_gate() {
  local repo="$1"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "gate check needs a git work tree: $repo"
  local base="$BASE_SHA"
  if [[ -z "$base" ]]; then
    if git -C "$repo" rev-parse --verify --quiet origin/main >/dev/null; then
      base="$(git -C "$repo" merge-base HEAD origin/main)"
    elif git -C "$repo" rev-parse --verify --quiet main >/dev/null; then
      base="$(git -C "$repo" merge-base HEAD main 2>/dev/null || true)"
    fi
  fi
  [[ -n "$base" ]] || fail "cannot resolve merge base; pass --base SHA"
  # Introduction of the gate (files absent on base) may land with other files.
  # `ls-tree PATH` exits 0 with empty output when PATH is missing — check the
  # blob/tree object, not the command's exit code.
  local existed=0
  git -C "$repo" cat-file -e "$base:$SUITE_REL" 2>/dev/null && existed=1
  git -C "$repo" cat-file -e "$base:.eposforge/source-control-ci/posix-standing-runner" 2>/dev/null && existed=1
  (( existed )) || { echo "run-standing: gate not on $base — introduction allowed"; return 0; }

  local changed gate_changed=0 other_changed=0 rel
  changed="$(git -C "$repo" diff --name-only "$base"...HEAD)"
  # Uncommitted work counts too: an agent editing the gate in the same
  # uncommitted change as the code it is scored on is the same defect.
  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    changed+=$'\n'"$(git -C "$repo" diff --name-only; git -C "$repo" diff --name-only --cached)"
  fi
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if is_gate_path "$rel"; then
      gate_changed=1
    else
      other_changed=1
    fi
  done <<<"$changed"
  if (( gate_changed && other_changed )); then
    fail "gate files and scored files changed in the same range ($base...HEAD); split the change"
  fi
  echo "run-standing: gate untouched or gate-only change"
}

case "$MODE" in
  list)
    list_entries "$(default_repo)"
    ;;
  accepts)
    [[ -n "$ACCEPTS_CMD" ]] || die "--accepts needs a command"
    if standing_accepts "$(default_repo)" "$ACCEPTS_CMD"; then
      echo "accepted"
      exit 0
    fi
    fail "not a repo-local standing check: $ACCEPTS_CMD"
    ;;
  gate)
    check_gate "$(default_repo)"
    ;;
  run)
    if (( ${#REPOS[@]} == 0 )); then
      REPOS=("$(default_repo)")
    fi
    for r in "${REPOS[@]}"; do
      run_repo "$(repo_root "$r")"
    done
    if [[ -n "$HELD_OUT" ]]; then
      run_held_out "$HELD_OUT"
    fi
    ;;
  *) die "unknown mode $MODE" ;;
esac
