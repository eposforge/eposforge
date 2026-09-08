#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# check-vehicle-class.sh — Gate G1 (Standard 15, requirement 2/3): a file
# ADDED under a declared code root must carry a `# vehicle-class: <class>`
# marker naming one of the five classes in the vehicle-class table.
#
# Declared code roots (Standard 15 requirement 7, v1 scan set): any path
# under `.eposforge/` with a `scripts/` path component, and `skills/*/scripts/`.
# Product `code_globs` join this set later, when a registry exists on disk.
#
# Scan set is files ADDED, not touched — a `vehicle-class:` marker is a
# one-time classification at commit time, not a standing property re-checked
# on every edit (Standard 15 requirement 2, "before committed code").
#
# Modes:
#   --staged                     Added-and-staged files (for pre-commit)
#   --changed-against <git-ref>  Files added since ref (for CI)
#   (default)                    Every tracked file in the code roots (ratchet
#                                 stage "fail-remaining"; not wired into CI yet)
#
# Invoked from:
#   * pre-commit hook fragment at
#     .eposforge/source-control-ci/github-and-actions/scripts/hooks/pre-commit
#   * CI workflow .github/workflows/program-first-gates.yml
#
# Cross-host: runs on Linux (srv-docker-hp) and Windows Git Bash (ws-dev-1).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MODE="all"
BASE_REF=""
if [[ "${1:-}" == "--staged" ]]; then
  MODE="staged"
elif [[ "${1:-}" == "--changed-against" ]]; then
  MODE="changed"
  BASE_REF="${2:-}"
  if [[ -z "${BASE_REF}" ]]; then
    echo "ERROR: --changed-against requires a git ref" >&2
    exit 1
  fi
fi

VALID_CLASSES="host-ci-glue in-repo-pipeline library-or-service vendor-locked-runtime disposable-spike"
MARKER_LOOSE='vehicle-class:'

in_code_root() {
  local p="$1"
  [[ "$p" == .eposforge/* && "$p" == */scripts/* ]] && return 0
  [[ "$p" == skills/*/scripts/* ]] && return 0
  return 1
}

should_skip_file() {
  case "$1" in
    *.pyc|*.pyo|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip|*.tar|*.gz|*.7z|*.dll|*.exe|*.so|*.dylib) return 0 ;;
    */__pycache__/*|*/.venv/*|*/node_modules/*) return 0 ;;
  esac
  return 1
}

is_valid_class() {
  local v="$1" c
  for c in $VALID_CLASSES; do
    [[ "$v" == "$c" ]] && return 0
  done
  return 1
}

# Comment-prefix agnostic: Standard 15 names no programming language, so the
# marker must be recognizable under any of this repo's actual comment
# syntaxes, not just '#' (bash/python/ps1 today; '//' and '--' for whatever
# non-# language shows up under a code root next).
COMMENT_PREFIX_RE='(#|//|--)'

# Prints "missing" | "invalid:<value>" | "" (ok) for a given file's content.
classify_content() {
  local content="$1"
  local line value
  line="$(printf '%s\n' "$content" | grep -m1 -E "^[[:space:]]*${COMMENT_PREFIX_RE}[[:space:]]*${MARKER_LOOSE}" || true)"
  if [[ -z "$line" ]]; then
    echo "missing"
    return
  fi
  # '@' delimiters, not '/': COMMENT_PREFIX_RE contains a literal '//' branch
  # (and the '|' alternation operator), either of which would corrupt a
  # sed s/// built with '/' as the delimiter.
  value="$(printf '%s' "$line" | sed -E "s@^[[:space:]]*${COMMENT_PREFIX_RE}[[:space:]]*${MARKER_LOOSE}[[:space:]]*@@; s@[[:space:]]+\$@@")"
  if is_valid_class "$value"; then
    echo ""
  else
    echo "invalid:${value}"
  fi
}

missing=()
invalid=()

check_worktree_file() {
  local f="$1"
  in_code_root "$f" || return 0
  should_skip_file "$f" && return 0
  [[ -f "$f" ]] || return 0
  grep -Iq . "$f" || return 0  # binary, skip
  local result
  result="$(classify_content "$(cat "$f")")"
  case "$result" in
    missing) missing+=("$f") ;;
    invalid:*) invalid+=("$f (${result#invalid:})") ;;
  esac
}

check_staged_file() {
  local f="$1"
  in_code_root "$f" || return 0
  should_skip_file "$f" && return 0
  git cat-file -e ":${f}" 2>/dev/null || return 0
  local content
  content="$(git show ":${f}")"
  printf '%s' "$content" | grep -Iq . || return 0
  local result
  result="$(classify_content "$content")"
  case "$result" in
    missing) missing+=("$f") ;;
    invalid:*) invalid+=("$f (${result#invalid:})") ;;
  esac
}

if [[ "$MODE" == "staged" ]]; then
  while IFS= read -r -d '' f; do
    check_staged_file "$f"
  done < <(git diff --cached --name-only --diff-filter=A -z)
elif [[ "$MODE" == "changed" ]]; then
  while IFS= read -r -d '' f; do
    check_worktree_file "$f"
  done < <(git diff --name-only --diff-filter=A -z "${BASE_REF}...HEAD")
else
  while IFS= read -r -d '' f; do
    check_worktree_file "$f"
  done < <(git ls-files -z)
fi

if [[ "${#missing[@]}" -gt 0 || "${#invalid[@]}" -gt 0 ]]; then
  cat >&2 <<'MSG'
ERROR: G1 (Standard 15) — vehicle-class classification missing or invalid.

Every file added under a declared code root (.eposforge/**/scripts/** or
skills/*/scripts/**) must carry a one-line marker naming exactly one class:

  # vehicle-class: host-ci-glue | in-repo-pipeline | library-or-service | vendor-locked-runtime | disposable-spike

See 04-standards/15-program-first-procedures/program-first-procedures.md
for the table and what each class means. "It is the default" and "it is
quicker" are not valid reasons to skip this.
MSG
  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "" >&2
    echo "Missing marker:" >&2
    for f in "${missing[@]}"; do echo "  $f" >&2; done
  fi
  if [[ "${#invalid[@]}" -gt 0 ]]; then
    echo "" >&2
    echo "Marker present but not a recognized class:" >&2
    for f in "${invalid[@]}"; do echo "  $f" >&2; done
  fi
  exit 1
fi

echo "G1 vehicle-class check passed (${MODE})."
