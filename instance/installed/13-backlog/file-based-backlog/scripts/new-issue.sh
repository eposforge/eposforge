#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# Discover adoption-root: workspace-file → BACKLOG_ROOTS env → git-root fallback.
_ws="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"
BACKLOG_DIR=""
if [[ -n "${_ws}" && -f "${_ws}" ]]; then
  _ws_dir="$(dirname "$(realpath "${_ws}")")"
  while IFS= read -r _folder; do
    [[ -z "${_folder}" ]] && continue
    if [[ "${_folder}" = /* ]]; then _cand="${_folder}/backlog"; else _cand="${_ws_dir}/${_folder}/backlog"; fi
    if [[ -f "${_cand}/config.toml" ]]; then BACKLOG_DIR="$(realpath "${_cand}")"; break; fi
  done < <(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); [print(f.get('path','')) for f in d.get('folders',[])]" "${_ws}" 2>/dev/null)
fi
if [[ -z "${BACKLOG_DIR}" && -n "${BACKLOG_ROOTS:-}" ]]; then
  _first="${BACKLOG_ROOTS%%:*}"
  [[ -f "${_first}/backlog/config.toml" ]] && BACKLOG_DIR="${_first}/backlog"
fi
[[ -z "${BACKLOG_DIR}" ]] && BACKLOG_DIR="${REPO_ROOT}/backlog"
CONFIG_FILE="${BACKLOG_DIR}/config.toml"
ACTIVE_FILE="${BACKLOG_DIR}/backlog.md"
SLATED_FILE="${BACKLOG_DIR}/backlog-slated.md"
ARCHIVE_FILE="${BACKLOG_DIR}/backlog-archive.md"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: missing config file: ${CONFIG_FILE}" >&2
  exit 1
fi

prefix="$(sed -nE 's/^[[:space:]]*prefix[[:space:]]*=[[:space:]]*"([A-Z]+)"[[:space:]]*$/\1/p' "${CONFIG_FILE}" | head -n1)"
if [[ -z "${prefix}" ]]; then
  echo "ERROR: could not parse prefix from ${CONFIG_FILE}" >&2
  exit 1
fi

max_id=0
for file in "${ACTIVE_FILE}" "${SLATED_FILE}" "${ARCHIVE_FILE}"; do
  [[ -f "$file" ]] || continue
  while IFS= read -r id; do
    num="${id#${prefix}-}"
    if [[ "$num" =~ ^[0-9]+$ ]] && (( 10#$num > max_id )); then
      max_id=$((10#$num))
    fi
  done < <(grep -oE "${prefix}-[0-9]{3,}" "$file" | sort -u || true)
done

next=$((max_id + 1))
next_id="$(printf "%s-%03d" "$prefix" "$next")"
today="$(date +%F)"

cat >>"${ACTIVE_FILE}" <<EOF

## Issue ${next_id} — <title>
ID: ${next_id}
Title: <title>
Date: ${today}
Status: open
Effort: S
Fix surface: <set-from-config>
Verify with: <observable-check>
EOF

echo "${next_id}"