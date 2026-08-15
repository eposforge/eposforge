# claim-cwd.sh — where a mechanical claim's evidence_cmd runs. Source, do not execute.
#
# resolve_claim_cwd <handoff> <claim_cwd> <files_csv> <fallback>
# Prints one directory and returns 0 when it can name exactly one place to run.
# Returns 1 when it cannot. Never prints scope[0] just because it is first —
# that is how a true claim about a later repo becomes a harness failure.
#
# Resolution, in order:
#   1. claim.cwd — a directory in/under a scope repo, or a scope policy_key /
#      repo_path / basename
#   2. files[]  — the unique scope repo that contains every resolvable path
#   3. fallback — operator --cwd, used as-is if it is a directory
#   4. the only scope entry, when the handoff names exactly one repo

_cc_canon() {
  local p="$1"
  [[ -n "$p" && -d "$p" ]] || return 1
  ( cd "$p" && pwd -P )
}

_cc_scope_rows() {
  jq -r '.scope[] | [.repo_path, .policy_key] | @tsv' "$1"
}

# $1 candidate (canonical dir) $2 handoff — 0 if candidate is a scope repo or a subdir of one.
_cc_in_scope() {
  local cand="$1" hand="$2" repo key cr
  while IFS=$'\t' read -r repo key; do
    [[ -n "$repo" ]] || continue
    cr="$(_cc_canon "$repo" 2>/dev/null)" || cr="$repo"
    if [[ "$cand" == "$cr" || "$cand" == "$cr"/* ]]; then
      return 0
    fi
  done < <(_cc_scope_rows "$hand")
  return 1
}

resolve_claim_cwd() {
  local hand="$1" claim_cwd="${2:-}" files="${3:-}" fallback="${4:-}"
  local repo key cand f matches nmatch chosen cr

  if [[ -n "$claim_cwd" ]]; then
    if [[ -d "$claim_cwd" ]]; then
      cand="$(_cc_canon "$claim_cwd")" || return 1
      _cc_in_scope "$cand" "$hand" || return 1
      printf '%s\n' "$cand"
      return 0
    fi
    while IFS=$'\t' read -r repo key; do
      [[ -n "$repo" ]] || continue
      if [[ "$claim_cwd" == "$key" || "$claim_cwd" == "$repo" || "$claim_cwd" == "$(basename "$repo")" ]]; then
        cand="$(_cc_canon "$repo")" || return 1
        printf '%s\n' "$cand"
        return 0
      fi
    done < <(_cc_scope_rows "$hand")
    return 1
  fi

  if [[ -n "$files" ]]; then
    chosen=""
    local any=0
    local IFS=','
    # shellcheck disable=SC2086
    set -- $files
    unset IFS
    for f in "$@"; do
      f="${f#"${f%%[![:space:]]*}"}"
      f="${f%"${f##*[![:space:]]}"}"
      [[ -n "$f" ]] || continue
      f="${f#./}"
      matches=""
      while IFS=$'\t' read -r repo key; do
        [[ -n "$repo" ]] || continue
        cr="$(_cc_canon "$repo" 2>/dev/null)" || cr="$repo"
        if [[ "$f" == /* ]]; then
          if [[ "$f" == "$cr" || "$f" == "$cr"/* ]]; then
            matches+="${cr}"$'\n'
          fi
        elif [[ -e "$cr/$f" ]]; then
          matches+="${cr}"$'\n'
        fi
      done < <(_cc_scope_rows "$hand")
      matches="$(printf '%s' "$matches" | sed '/^$/d' | sort -u)"
      [[ -n "$matches" ]] || continue
      nmatch="$(printf '%s\n' "$matches" | grep -c .)"
      [[ "$nmatch" -eq 1 ]] || continue
      cr="$(printf '%s' "$matches")"
      if [[ "$any" -eq 0 ]]; then
        chosen="$cr"
        any=1
      elif [[ "$chosen" != "$cr" ]]; then
        return 1
      fi
    done
    if [[ "$any" -eq 1 ]]; then
      printf '%s\n' "$chosen"
      return 0
    fi
  fi

  if [[ -n "$fallback" && -d "$fallback" ]]; then
    cand="$(_cc_canon "$fallback")" || return 1
    printf '%s\n' "$cand"
    return 0
  fi

  if [[ "$(jq -r '.scope | length' "$hand")" == "1" ]]; then
    repo="$(jq -r '.scope[0].repo_path' "$hand")"
    cand="$(_cc_canon "$repo")" || return 1
    printf '%s\n' "$cand"
    return 0
  fi

  return 1
}
