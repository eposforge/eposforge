#!/usr/bin/env bash
# resolve-backlog.sh — source this file to populate BACKLOG_DIR.
#
# Resolution precedence (single-root scripts):
#   1. BACKLOG_ROOTS env  — first colon-separated entry; <entry>/backlog/config.toml
#   2. cwd walk-up        — from $PWD upward: <dir>/backlog/config.toml then
#                           <dir>/eposforge/backlog/config.toml (D1: depth-tolerant)
#   3. VS Code workspace  — VSCODE_WORKSPACE_FILE / WORKSPACE_FILE; same depth probes
#   4. <git-root>/backlog — back-compat fallback (fails gracefully if no config.toml)
#
# After sourcing, BACKLOG_DIR is an absolute path to the resolved backlog directory.
# If no config.toml exists at the resolved path, the caller should emit the bootstrap
# message and exit 1.
#
# BACKLOG_HOME is reserved for the framework tooling source path (used by
# sync-tooling.sh and the version drift check). Do NOT use BACKLOG_HOME for the
# data root — that is BACKLOG_ROOTS.

_RESOLVE_BACKLOG_CWD="${_RESOLVE_BACKLOG_CWD:-$PWD}"

BACKLOG_DIR=""

# Tier 1 — BACKLOG_ROOTS env
if [[ -n "${BACKLOG_ROOTS:-}" ]]; then
  _first="${BACKLOG_ROOTS%%:*}"
  if [[ -f "${_first}/backlog/config.toml" ]]; then
    BACKLOG_DIR="$(realpath "${_first}/backlog")"
  fi
fi

# Tier 2 — cwd walk-up
if [[ -z "${BACKLOG_DIR}" ]]; then
  _walk="${_RESOLVE_BACKLOG_CWD}"
  while [[ "${_walk}" != "/" ]]; do
    if [[ -f "${_walk}/backlog/config.toml" ]]; then
      BACKLOG_DIR="$(realpath "${_walk}/backlog")"
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
      if [[ -f "${_base}/eposforge/backlog/config.toml" ]]; then
        BACKLOG_DIR="$(realpath "${_base}/eposforge/backlog")"
        break
      fi
    done < <(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); [print(f.get('path','')) for f in d.get('folders',[])]" "${_ws}" 2>/dev/null)
    unset _ws _ws_dir _folder _base
  fi
fi

# Tier 4 — git-root/backlog (back-compat fallback)
if [[ -z "${BACKLOG_DIR}" ]]; then
  _git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "${_git_root}" ]]; then
    BACKLOG_DIR="${_git_root}/backlog"
  else
    BACKLOG_DIR="${PWD}/backlog"
  fi
  unset _git_root
fi

unset _first _RESOLVE_BACKLOG_CWD
