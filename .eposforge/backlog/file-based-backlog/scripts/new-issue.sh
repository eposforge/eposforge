#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR_NEW="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-backlog.sh
source "${SCRIPT_DIR_NEW}/resolve-backlog.sh"
CONFIG_FILE="${BACKLOG_DIR}/config.toml"
ACTIVE_FILE="${BACKLOG_DIR}/backlog.md"
SLATED_FILE="${BACKLOG_DIR}/backlog-slated.md"
ARCHIVE_FILE="${BACKLOG_DIR}/backlog-archive.md"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: no backlog found at ${CONFIG_FILE}." >&2
  echo "  Bootstrap: create ${BACKLOG_DIR}/config.toml with:" >&2
  echo '    prefix = "XX"' >&2
  echo "  Resolution order tried: BACKLOG_ROOTS env → cwd walk-up → VS Code workspace file → git-root fallback (backlog/.eposforge/eposforge)" >&2
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