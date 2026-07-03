#!/usr/bin/env bash
# install.sh — project canonical skills/<name>/ into a chosen agent surface.
#
# Usage:
#   install.sh <skill-name> --surface <surface> [--mode fork|consume] [--eposforge-home <path>]
#   install.sh --list
#   install.sh <skill-name> --uninstall --surface <surface>
#
# Surfaces (data-driven table at the bottom of this file):
#   claude-code-user          ~/.claude/skills/<name>/              symlink
#   claude-code-cmd           ~/.claude/commands/<name>.md          symlink (SKILL.md)
#   copilot-workspace-skill   <repo>/.github/skills/<name>/         symlink
#   copilot-workspace-prompt  <repo>/.github/prompts/<name>.md      symlink (SKILL.md)
#   copilot-user-remote       ~/.vscode-server/data/User/prompts/   copy-with-provenance
#   copilot-user-local        ~/.config/Code/User/prompts/          copy-with-provenance
#
# Modes:
#   consume (default) — source is EPOSFORGE_HOME/skills/<name> (or this clone)
#   fork              — source is <current-repo>/skills/<name>
#
# Environment:
#   EPOSFORGE_HOME — canonical eposforge clone root (default: script parent repo root)
#
# For script-calling skills, sets EPOSFORGE_HOME in any generated wrapper so
# the installed skill resolves framework tooling regardless of cwd.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
# Format: <surface-id>|<method>|<target-template>|<source-kind>|<source-template>
# Placeholders:
#   %n = skill name
#   %r = workspace repo root (for workspace surfaces)
#   %k = resolved skill root directory (skills/<name>)
SURFACES=(
  "claude-code-user|symlink|${HOME}/.claude/skills/%n|dir|%k"
  "claude-code-cmd|symlink|${HOME}/.claude/commands/%n.md|file|%k/SKILL.md"
  "copilot-workspace-skill|symlink|%r/.github/skills/%n|dir|%k"
  "copilot-workspace-prompt|symlink|%r/.github/prompts/%n.md|file|%k/SKILL.md"
  "copilot-user-remote|copy|${HOME}/.vscode-server/data/User/prompts/%n.md|file|%k/SKILL.md"
  "copilot-user-local|copy|${HOME}/.config/Code/User/prompts/%n.md|file|%k/SKILL.md"
)

_surface_row() {
  local id="$1"
  for entry in "${SURFACES[@]}"; do
    local row_id="${entry%%|*}"
    if [[ "${row_id}" == "${id}" ]]; then
      echo "${entry}"
      return 0
    fi
  done
  return 1
}

_field() {
  local row="$1" idx="$2"
  IFS='|' read -r f1 f2 f3 f4 f5 <<< "${row}"
  case "${idx}" in
    1) echo "${f1}" ;;
    2) echo "${f2}" ;;
    3) echo "${f3}" ;;
    4) echo "${f4}" ;;
    5) echo "${f5}" ;;
    *) return 1 ;;
  esac
}

_render_template() {
  local template="$1" skill="$2" repo="$3" skill_root="$4"
  if [[ "${template}" == *"%r"* && -z "${repo}" ]]; then
    return 1
  fi
  template="${template//%n/${skill}}"
  template="${template//%r/${repo}}"
  template="${template//%k/${skill_root}}"
  echo "${template}"
}

_surface_targets_for_skill() {
  local skill="$1" repo="$2" skill_root="$3"
  for entry in "${SURFACES[@]}"; do
    local sid target_tpl target
    sid="$(_field "${entry}" 1)"
    target_tpl="$(_field "${entry}" 3)"
    target="$(_render_template "${target_tpl}" "${skill}" "${repo}" "${skill_root}" 2>/dev/null || true)"
    if [[ -z "${target}" ]]; then
      echo "  ${sid}  (requires --repo)"
      continue
    fi
    if [[ -L "${target}" ]] || [[ -e "${target}" ]]; then
      echo "  ${sid}  installed at ${target}"
    else
      echo "  ${sid}  not installed (${target})"
    fi
  done
}

_list_surfaces() {
  echo "Available surfaces:"
  for entry in "${SURFACES[@]}"; do
    local id method target kind source
    id="$(_field "${entry}" 1)"
    method="$(_field "${entry}" 2)"
    target="$(_field "${entry}" 3)"
    kind="$(_field "${entry}" 4)"
    source="$(_field "${entry}" 5)"
    printf "  %-26s method:%-7s target:%s  source:%s(%s)\n" "${id}" "${method}" "${target}" "${source}" "${kind}"
  done
}

_normalize_compare_file() {
  local in="$1" out="$2"
  if [[ -f "${in}" ]] && head -n 1 "${in}" | grep -q '^# source: '; then
    tail -n +2 "${in}" > "${out}"
  else
    cat "${in}" > "${out}"
  fi
}

_normalize_compare_tree() {
  local in_dir="$1" out_dir="$2"
  mkdir -p "${out_dir}"
  cp -r "${in_dir}/." "${out_dir}/"
  if [[ -f "${out_dir}/SKILL.md" ]] && head -n 1 "${out_dir}/SKILL.md" | grep -q '^# source: '; then
    local tmp
    tmp="$(mktemp)"
    tail -n +2 "${out_dir}/SKILL.md" > "${tmp}"
    mv "${tmp}" "${out_dir}/SKILL.md"
  fi
}

# --- List mode ---------------------------------------------------------------
if [[ ${DO_LIST} -eq 1 ]]; then
  CANONICAL_SKILLS_DIR="${EPOSFORGE_HOME}/skills"
  if [[ ! -d "${CANONICAL_SKILLS_DIR}" ]]; then
    echo "ERROR: canonical skills directory not found: ${CANONICAL_SKILLS_DIR}" >&2
    exit 1
  fi
  echo "Canonical skills in ${CANONICAL_SKILLS_DIR}:"
  for d in "${CANONICAL_SKILLS_DIR}"/*/; do
    [[ -d "${d}" ]] || continue
    name="$(basename "${d}")"
    skill_root="${CANONICAL_SKILLS_DIR}/${name}"
    echo "  ${name}"
    _surface_targets_for_skill "${name}" "${COPILOT_WORKSPACE_REPO:-}" "${skill_root}" | sed 's/^/    /'
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

if [[ "${MODE}" != "consume" && "${MODE}" != "fork" ]]; then
  echo "ERROR: --mode must be 'consume' or 'fork' (got '${MODE}')" >&2
  exit 2
fi

ROW="$(_surface_row "${SURFACE}" || { echo "ERROR: unknown surface '${SURFACE}'" >&2; exit 2; })"
METHOD="$(_field "${ROW}" 2)"
TARGET_TEMPLATE="$(_field "${ROW}" 3)"
SOURCE_KIND="$(_field "${ROW}" 4)"
SOURCE_TEMPLATE="$(_field "${ROW}" 5)"

if [[ "${TARGET_TEMPLATE}" == *"%r"* && -z "${COPILOT_WORKSPACE_REPO}" ]]; then
  COPILOT_WORKSPACE_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "${COPILOT_WORKSPACE_REPO}" ]]; then
    echo "ERROR: surface '${SURFACE}' requires --repo <repo-root> (or run in a git worktree)" >&2
    exit 2
  fi
fi

if [[ "${MODE}" == "consume" ]]; then
  SKILL_ROOT="${EPOSFORGE_HOME}/skills/${SKILL_NAME}"
else
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "${repo_root}" ]]; then
    echo "ERROR: fork mode requires a git repository" >&2
    exit 1
  fi
  SKILL_ROOT="${repo_root}/skills/${SKILL_NAME}"
fi

if [[ ! -d "${SKILL_ROOT}" ]]; then
  echo "ERROR: skill '${SKILL_NAME}' not found at ${SKILL_ROOT}" >&2
  exit 1
fi

TARGET="$(_render_template "${TARGET_TEMPLATE}" "${SKILL_NAME}" "${COPILOT_WORKSPACE_REPO:-}" "${SKILL_ROOT}" || {
  echo "ERROR: failed to resolve target for surface '${SURFACE}'" >&2
  exit 2
})"
SOURCE="$(_render_template "${SOURCE_TEMPLATE}" "${SKILL_NAME}" "${COPILOT_WORKSPACE_REPO:-}" "${SKILL_ROOT}")"

if [[ "${SOURCE_KIND}" == "dir" && ! -d "${SOURCE}" ]]; then
  echo "ERROR: expected directory source, not found: ${SOURCE}" >&2
  exit 1
fi
if [[ "${SOURCE_KIND}" == "file" && ! -f "${SOURCE}" ]]; then
  echo "ERROR: expected file source, not found: ${SOURCE}" >&2
  exit 1
fi

PROVENANCE_HEADER="# source: ${SOURCE}@$(git -C "${EPOSFORGE_HOME}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

_install_symlink() {
  local src="$1" dst="$2" src_kind="$3"
  if [[ -L "${dst}" ]]; then
    local existing
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
  echo "Installed (symlink ${src_kind}): ${dst} → ${src}"
}

_install_copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "${dst}")"
  if [[ -f "${dst}" ]]; then
    local nsrc ndst
    nsrc="$(mktemp)"
    ndst="$(mktemp)"
    cat "${src}" > "${nsrc}"
    _normalize_compare_file "${dst}" "${ndst}"
    if cmp -s "${nsrc}" "${ndst}"; then
      echo "OK (up to date): ${dst}"
      rm -f "${nsrc}" "${ndst}"
      return 0
    fi
    rm -f "${nsrc}" "${ndst}"
    echo "DRIFT detected at ${dst} — updating..."
  elif [[ -e "${dst}" ]]; then
    echo "ERROR: ${dst} exists and is not a regular file" >&2
    exit 1
  fi

  local tmp
  tmp="$(mktemp)"
  { echo "${PROVENANCE_HEADER}"; cat "${src}"; } > "${tmp}"
  mv "${tmp}" "${dst}"
  echo "Installed (copy with provenance): ${dst}"
  echo "  ${PROVENANCE_HEADER}"
}

_install_copy_dir() {
  local src="$1" dst="$2"
  if [[ -d "${dst}" ]]; then
    local lhs rhs
    lhs="$(mktemp -d)"
    rhs="$(mktemp -d)"
    _normalize_compare_tree "${src}" "${lhs}/src"
    _normalize_compare_tree "${dst}" "${rhs}/dst"
    if diff -rq "${lhs}/src" "${rhs}/dst" > /dev/null 2>&1; then
      echo "OK (up to date): ${dst}"
      rm -rf "${lhs}" "${rhs}"
      return 0
    fi
    rm -rf "${lhs}" "${rhs}"
    echo "DRIFT detected at ${dst} — updating..."
  elif [[ -e "${dst}" ]]; then
    echo "ERROR: ${dst} exists and is not a directory" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${dst}")"
  rm -rf "${dst}"
  cp -r "${src}" "${dst}"
  local skill_md
  skill_md="${dst}/SKILL.md"
  if [[ -f "${skill_md}" ]]; then
    local tmp
    tmp="$(mktemp)"
    { echo "${PROVENANCE_HEADER}"; cat "${skill_md}"; } > "${tmp}"
    mv "${tmp}" "${skill_md}"
  fi
  echo "Installed (copy with provenance): ${dst}"
  echo "  ${PROVENANCE_HEADER}"
}

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

case "${METHOD}" in
  symlink) _install_symlink "${SOURCE}" "${TARGET}" "${SOURCE_KIND}" ;;
  copy)
    case "${SOURCE_KIND}" in
      file) _install_copy_file "${SOURCE}" "${TARGET}" ;;
      dir)  _install_copy_dir  "${SOURCE}" "${TARGET}" ;;
      *)    echo "ERROR: unknown source kind '${SOURCE_KIND}'" >&2; exit 2 ;;
    esac
    ;;
  *)       echo "ERROR: unknown method '${METHOD}'" >&2; exit 2 ;;
esac

# For script-calling skills: remind operator to set EPOSFORGE_HOME
if grep -qr "EPOSFORGE_HOME" "${SKILL_ROOT}/" 2>/dev/null; then
  echo ""
  echo "  NOTE: this skill uses EPOSFORGE_HOME to locate framework scripts."
  echo "  Ensure EPOSFORGE_HOME is set to: ${EPOSFORGE_HOME}"
  echo "  (e.g. add to ~/.bashrc or ~/.profile: export EPOSFORGE_HOME=${EPOSFORGE_HOME})"
fi
