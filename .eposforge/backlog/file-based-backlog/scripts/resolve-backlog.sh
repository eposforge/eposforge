#!/usr/bin/env bash
# resolve-backlog.sh — source this file to populate BACKLOG_DIR.
#
# Resolution precedence (single-root scripts):
#   1. BACKLOG_ROOTS env  — first colon-separated entry; probe:
#                           <entry>/backlog/config.toml
#                           <entry>/.eposforge/backlog/config.toml
#                           <entry>/eposforge/backlog/config.toml
#   2. cwd walk-up        — from $PWD upward: same probes (depth-tolerant)
#   3. VS Code workspace  — VSCODE_WORKSPACE_FILE / WORKSPACE_FILE; same probes
#   4. git-root fallback  — first existing probe under git root, else <git-root>/backlog
#
# After sourcing, BACKLOG_DIR is an absolute path to the resolved backlog directory.
# If no config.toml exists at the resolved path, the caller should emit the bootstrap
# message and exit 1.
#
# BACKLOG_DIRS is a parallel ARRAY holding EVERY backlog dir the resolution found,
# with BACKLOG_DIR as its first element (eposforge:EF-078). Tier 1 contributes one
# entry per colon-separated `BACKLOG_ROOTS` entry that has a config; tiers 2-4 are
# single-root by construction and yield exactly one. Scripts that act on the whole
# set (lint, sweep) iterate BACKLOG_DIRS; scripts that write into one repo
# (new-issue) keep using BACKLOG_DIR. Reading only BACKLOG_DIR when the caller
# named several roots is the EF-078 defect — it silently skipped every root but
# the first.
#
# BACKLOG_HOME is reserved for the framework tooling source path (used by
# sync-tooling.sh and the version drift check). Do NOT use BACKLOG_HOME for the
# data root — that is BACKLOG_ROOTS.

_RESOLVE_BACKLOG_CWD="${_RESOLVE_BACKLOG_CWD:-$PWD}"

BACKLOG_DIR=""
BACKLOG_DIRS=()

# Append "$1"'s backlog dir to BACKLOG_DIRS if one of the three layouts has a
# config there and it is not already present. Returns 1 when nothing was found.
_resolve_backlog_probe() {
  local base="$1" found=""
  if [[ -f "${base}/backlog/config.toml" ]]; then
    found="$(realpath "${base}/backlog")"
  elif [[ -f "${base}/.eposforge/backlog/config.toml" ]]; then
    found="$(realpath "${base}/.eposforge/backlog")"
  elif [[ -f "${base}/eposforge/backlog/config.toml" ]]; then
    found="$(realpath "${base}/eposforge/backlog")"
  fi
  [[ -z "${found}" ]] && return 1
  local seen
  for seen in ${BACKLOG_DIRS+"${BACKLOG_DIRS[@]}"}; do
    [[ "${seen}" == "${found}" ]] && return 0
  done
  BACKLOG_DIRS+=("${found}")
  return 0
}

# Tier 1 — BACKLOG_ROOTS env. EVERY entry is probed, in order, not just the first
# (eposforge:EF-078). An entry with no config is skipped rather than fatal: the list
# is a superset of what any one machine has checked out, and refusing the whole run
# for one absent sibling would make the multi-root form unusable exactly where it
# matters. The first entry that DOES resolve stays BACKLOG_DIR, so single-root
# callers are unaffected.
if [[ -n "${BACKLOG_ROOTS:-}" ]]; then
  while IFS= read -r -d ':' _entry || [[ -n "${_entry}" ]]; do
    [[ -z "${_entry}" ]] && continue
    _resolve_backlog_probe "${_entry}" || true
  done < <(printf '%s:' "${BACKLOG_ROOTS}")
  if (( ${#BACKLOG_DIRS[@]} > 0 )); then
    BACKLOG_DIR="${BACKLOG_DIRS[0]}"
  fi
  unset _entry
fi

# Tier 2 — cwd walk-up
if [[ -z "${BACKLOG_DIR}" ]]; then
  _walk="${_RESOLVE_BACKLOG_CWD}"
  while [[ "${_walk}" != "/" ]]; do
    if [[ -f "${_walk}/backlog/config.toml" ]]; then
      BACKLOG_DIR="$(realpath "${_walk}/backlog")"
      break
    fi
    if [[ -f "${_walk}/.eposforge/backlog/config.toml" ]]; then
      BACKLOG_DIR="$(realpath "${_walk}/.eposforge/backlog")"
      break
    fi
    if [[ -f "${_walk}/eposforge/backlog/config.toml" ]]; then
      BACKLOG_DIR="$(realpath "${_walk}/eposforge/backlog")"
      break
    fi
    _walk="$(dirname "${_walk}")"
  done
  unset _walk
fi

# Tier 3 — VS Code workspace file
if [[ -z "${BACKLOG_DIR}" ]]; then
  _ws="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"
  if [[ -n "${_ws}" && -f "${_ws}" ]]; then
    _ws_dir="$(dirname "$(realpath "${_ws}")")"
    while IFS= read -r _folder; do
      [[ -z "${_folder}" ]] && continue
      if [[ "${_folder}" = /* ]]; then
        _base="${_folder}"
      else
        _base="${_ws_dir}/${_folder}"
      fi
      if [[ -f "${_base}/backlog/config.toml" ]]; then
        BACKLOG_DIR="$(realpath "${_base}/backlog")"
        break
      fi
      if [[ -f "${_base}/.eposforge/backlog/config.toml" ]]; then
        BACKLOG_DIR="$(realpath "${_base}/.eposforge/backlog")"
        break
      fi
      if [[ -f "${_base}/eposforge/backlog/config.toml" ]]; then
        BACKLOG_DIR="$(realpath "${_base}/eposforge/backlog")"
        break
      fi
    done < <(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); [print(f.get('path','')) for f in d.get('folders',[])]" "${_ws}" 2>/dev/null)
    unset _ws _ws_dir _folder _base
  fi
fi

# Tier 4 — git-root fallback (prefer existing config locations)
if [[ -z "${BACKLOG_DIR}" ]]; then
  _git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "${_git_root}" ]]; then
    if [[ -f "${_git_root}/backlog/config.toml" ]]; then
      BACKLOG_DIR="${_git_root}/backlog"
    elif [[ -f "${_git_root}/.eposforge/backlog/config.toml" ]]; then
      BACKLOG_DIR="${_git_root}/.eposforge/backlog"
    elif [[ -f "${_git_root}/eposforge/backlog/config.toml" ]]; then
      BACKLOG_DIR="${_git_root}/eposforge/backlog"
    else
      BACKLOG_DIR="${_git_root}/backlog"
    fi
  else
    BACKLOG_DIR="${PWD}/backlog"
  fi
  unset _git_root
fi

# Tiers 2-4 each resolve exactly one dir, so the set is that dir. Deliberate
# asymmetry with tier 1 (eposforge:EF-078): `BACKLOG_ROOTS` is an explicit set the
# caller chose, whereas the cwd walk-up, the VS Code workspace file and the git-root
# fallback are all incidental to where the script happened to be run. Widening those
# to act on every sibling repo would mean a plain `lint-backlog.sh` — or a
# pre-commit hook — silently reaching into repos the caller never named. Note that
# lint's ID aggregation still spans every workspace folder; it is the set of files
# ACTED ON that stays narrow here.
if (( ${#BACKLOG_DIRS[@]} == 0 )) && [[ -n "${BACKLOG_DIR}" ]]; then
  BACKLOG_DIRS=("${BACKLOG_DIR}")
fi

unset -f _resolve_backlog_probe
unset _first _RESOLVE_BACKLOG_CWD
