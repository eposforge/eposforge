#!/usr/bin/env bash
# install.sh — project any canonical skills/<name>/ into a chosen agent surface.
#
# Usage:
#   install.sh <skill-name> --surface <surface> [--mode fork|consume] [--eposforge-home <path>]
#   install.sh --list
#   install.sh <skill-name> --uninstall --surface <surface>
#
# Surfaces (data-driven table at the bottom of this file):
#   claude-code-user   ~/.claude/skills/<name>/          symlink
#   claude-code-cmd    ~/.claude/commands/<name>.md       symlink (single-file skills)
#   copilot-workspace  <repo>/.github/skills/<name>/      symlink
#   copilot-user       ~/.vscode-server/data/User/prompts/ copy-with-provenance
#
# Modes:
#   consume (default) — target points into this eposforge clone (or EPOSFORGE_HOME clone)
#   fork              — target is an in-tree copy inside the current repo
#
# Environment:
#   EPOSFORGE_HOME — path to the canonical eposforge clone (default: directory containing
#                    this script's parent directory, i.e. the eposforge repo root)
#
# For script-calling skills, sets EPOSFORGE_HOME in any generated wrapper so
# the installed skill resolves framework tooling regardless of cwd.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL_SKILLS_DIR="${SCRIPT_DIR}"
EPOSFORGE_HOME="${EPOSFORGE_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

SKILL_NAME=""
SURFACE=""
MODE="consume"
DO_UNINSTALL=0
DO_LIST=0
COPILOT_WORKSPACE_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --surface)
      SURFACE="${2:?--surface requires a value}"
      shift 2
      ;;
    --mode)
      MODE="${2:?--mode requires a value}"
      shift 2
      ;;
    --uninstall)
      DO_UNINSTALL=1
      shift
      ;;
    --list)
      DO_LIST=1
      shift
      ;;
    --eposforge-home)
      EPOSFORGE_HOME="${2:?--eposforge-home requires a value}"
      shift 2
      ;;
    --repo)
      COPILOT_WORKSPACE_REPO="${2:?--repo requires a value}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -n "${SKILL_NAME}" ]]; then
        echo "ERROR: multiple skill names given: '${SKILL_NAME}' and '$1'" >&2
        exit 2
      fi
      SKILL_NAME="$1"
      shift
      ;;
  esac
done

# --- Surface table -----------------------------------------------------------
# Format: <surface-id>:<method>:<target-template>
# %n = skill name, %e = EPOSFORGE_HOME, %r = COPILOT_WORKSPACE_REPO
SURFACES=(
  "claude-code-user:symlink:${HOME}/.claude/skills/%n"
  "claude-code-cmd:symlink:${HOME}/.claude/commands/%n.md"
  "copilot-workspace:symlink:%r/.github/skills/%n"
  "copilot-user:copy:${HOME}/.vscode-server/data/User/prompts/%n"
)

_surface_method() {
  local id="$1"
  for entry in "${SURFACES[@]}"; do
    if [[ "${entry%%:*}" == "${id}" ]]; then
      local rest="${entry#*:}"
      echo "${rest%%:*}"
      return 0
    fi
  done
  return 1
}

_surface_target() {
  local id="$1" skill="$2" repo="${3:-}"
  for entry in "${SURFACES[@]}"; do
    if [[ "${entry%%:*}" == "${id}" ]]; then
      local tpl="${entry#*:*:}"
      tpl="${tpl//%n/${skill}}"
      tpl="${tpl//%e/${EPOSFORGE_HOME}}"
      tpl="${tpl//%r/${repo}}"
      echo "${tpl}"
      return 0
    fi
  done
  return 1
}

_list_surfaces() {
  echo "Available surfaces:"
  for entry in "${SURFACES[@]}"; do
    local id="${entry%%:*}"
    local rest="${entry#*:}"
    local method="${rest%%:*}"
    printf "  %-22s  method: %s\n" "${id}" "${method}"
  done
}

# --- List mode ---------------------------------------------------------------
if [[ ${DO_LIST} -eq 1 ]]; then
  echo "Canonical skills in ${CANONICAL_SKILLS_DIR}:"
  for d in "${CANONICAL_SKILLS_DIR}"/*/; do
    [[ -d "${d}" ]] || continue
    name="$(basename "${d}")"
    echo "  ${name}"
    # Report known installations
    for entry in "${SURFACES[@]}"; do
      sid="${entry%%:*}"
      target="$(_surface_target "${sid}" "${name}" "${COPILOT_WORKSPACE_REPO:-}" 2>/dev/null || true)"
      [[ -z "${target}" ]] && continue
      if [[ -L "${target}" ]] || [[ -e "${target}" ]]; then
        echo "    → installed: ${sid} at ${target}"
      fi
    done
  done
  echo ""
  _list_surfaces
  exit 0
fi

# --- Validate skill name and surface ----------------------------------------
if [[ -z "${SKILL_NAME}" ]]; then
  echo "ERROR: skill name required. Usage: install.sh <skill-name> --surface <surface>" >&2
  echo "" >&2
  _list_surfaces >&2
  exit 2
fi
if [[ -z "${SURFACE}" ]]; then
  echo "ERROR: --surface required" >&2
  _list_surfaces >&2
  exit 2
fi

SKILL_SRC="${CANONICAL_SKILLS_DIR}/${SKILL_NAME}"
if [[ ! -d "${SKILL_SRC}" ]]; then
  echo "ERROR: skill '${SKILL_NAME}' not found at ${SKILL_SRC}" >&2
  exit 1
fi

METHOD="$(_surface_method "${SURFACE}" || { echo "ERROR: unknown surface '${SURFACE}'" >&2; exit 2; })"

if [[ "${SURFACE}" == "copilot-workspace" && -z "${COPILOT_WORKSPACE_REPO}" ]]; then
  COPILOT_WORKSPACE_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "${COPILOT_WORKSPACE_REPO}" ]]; then
    echo "ERROR: copilot-workspace surface requires --repo <repo-root> or a git working tree" >&2
    exit 2
  fi
fi

TARGET="$(_surface_target "${SURFACE}" "${SKILL_NAME}" "${COPILOT_WORKSPACE_REPO:-}")"

# --- Uninstall mode ----------------------------------------------------------
if [[ ${DO_UNINSTALL} -eq 1 ]]; then
  if [[ ! -e "${TARGET}" && ! -L "${TARGET}" ]]; then
    echo "Not installed: ${TARGET}"
    exit 0
  fi
  rm -rf "${TARGET}"
  echo "Uninstalled: ${TARGET}"
  exit 0
fi

# --- Install -----------------------------------------------------------------
PROVENANCE_HEADER="# source: ${SKILL_SRC}@$(git -C "${EPOSFORGE_HOME}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

_install_symlink() {
  local src="$1" dst="$2"
  if [[ -L "${dst}" ]]; then
    existing="$(readlink "${dst}")"
    if [[ "${existing}" == "${src}" ]]; then
      echo "OK (already linked): ${dst} → ${src}"
      return 0
    fi
    echo "DRIFT: ${dst} → ${existing} (expected → ${src})"
    echo "  Re-linking..."
    rm "${dst}"
  elif [[ -e "${dst}" ]]; then
    echo "ERROR: ${dst} exists and is not a symlink. Remove it first or use --mode fork." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${dst}")"
  ln -s "${src}" "${dst}"
  echo "Installed (symlink): ${dst} → ${src}"
}

_install_copy() {
  local src="$1" dst="$2"
  mkdir -p "${dst}"
  if [[ -d "${dst}" ]]; then
    # Drift check: compare canonical vs installed
    if diff -rq --exclude="*.md" "${src}" "${dst}" > /dev/null 2>&1; then
      # Check SKILL.md separately (provenance header may differ)
      src_body="$(tail -n +2 "${src}/SKILL.md" 2>/dev/null || true)"
      dst_body="$(tail -n +2 "${dst}/SKILL.md" 2>/dev/null || true)"
      if [[ "${src_body}" == "${dst_body}" ]]; then
        echo "OK (up to date): ${dst}"
        return 0
      fi
    fi
    echo "DRIFT detected at ${dst} — updating..."
  fi
  rm -rf "${dst}"
  cp -r "${src}" "${dst}"
  # Prepend provenance header to SKILL.md
  skill_md="${dst}/SKILL.md"
  if [[ -f "${skill_md}" ]]; then
    tmp="$(mktemp)"
    { echo "${PROVENANCE_HEADER}"; cat "${skill_md}"; } > "${tmp}"
    mv "${tmp}" "${skill_md}"
  fi
  echo "Installed (copy with provenance): ${dst}"
  echo "  ${PROVENANCE_HEADER}"
}

if [[ "${MODE}" == "consume" ]]; then
  canonical_src="${SKILL_SRC}"
else
  # fork mode: use path relative to repo root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "${repo_root}" ]]; then
    echo "ERROR: fork mode requires a git repository" >&2
    exit 1
  fi
  canonical_src="${repo_root}/${SKILL_NAME}"
  if [[ ! -d "${canonical_src}" ]]; then
    echo "ERROR: fork target ${canonical_src} does not exist" >&2
    exit 1
  fi
fi

case "${METHOD}" in
  symlink) _install_symlink "${canonical_src}" "${TARGET}" ;;
  copy)    _install_copy    "${canonical_src}" "${TARGET}" ;;
  *)       echo "ERROR: unknown method '${METHOD}'" >&2; exit 2 ;;
esac

# For script-calling skills: remind operator to set EPOSFORGE_HOME
if grep -qr "EPOSFORGE_HOME" "${SKILL_SRC}/" 2>/dev/null; then
  echo ""
  echo "  NOTE: this skill uses EPOSFORGE_HOME to locate framework scripts."
  echo "  Ensure EPOSFORGE_HOME is set to: ${EPOSFORGE_HOME}"
  echo "  (e.g. add to ~/.bashrc or ~/.profile: export EPOSFORGE_HOME=${EPOSFORGE_HOME})"
fi
