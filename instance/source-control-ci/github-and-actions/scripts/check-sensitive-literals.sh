#!/usr/bin/env bash
# check-sensitive-literals.sh
#
# Detects potentially sensitive literals in text files:
# - Private RFC1918 IPv4 addresses (LAN endpoints)
# - Machine-local absolute paths (common user/workstation paths)
#
# Modes:
#   --staged                     Scan staged content only (for pre-commit)
#   --changed-against <git-ref>  Scan files changed since ref (for CI)
#   (default)                    Scan all tracked files
set -euo pipefail

MODE="repo"
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

PRIVATE_IP_PATTERN='(^|[^0-9])(10\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])|192\.168\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])|172\.(1[6-9]|2[0-9]|3[0-1])\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9]))([^0-9]|$)'
LOCAL_PATH_PATTERN='([A-Za-z]:[\\/](Users|src|home|work|workspace|repos|projects)[\\/][^[:space:]"]+|/(Users|home)/[^/[:space:]]+/[^[:space:]"]+)'

has_errors=0

should_skip_file() {
  local file="$1"
  case "${file}" in
    *.pyc|*.pyo|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip|*.tar|*.gz|*.7z|*.dll|*.exe|*.so|*.dylib)
      return 0
      ;;
    */__pycache__/*|*/.venv/*|*/node_modules/*|*/graphrag/output/*|*/graphrag/cache/*)
      return 0
      ;;
  esac
  return 1
}

scan_file() {
  local file_path="$1"
  local label="$2"

  if grep -Iq . "${file_path}"; then
    local ip_hits
    local path_hits
    ip_hits=$(grep -nE "${PRIVATE_IP_PATTERN}" "${file_path}" || true)
    path_hits=$(grep -nE "${LOCAL_PATH_PATTERN}" "${file_path}" || true)

    if [[ -n "${ip_hits}" || -n "${path_hits}" ]]; then
      has_errors=1
      echo ""
      echo "Sensitive literal check failed in ${label}:"
      if [[ -n "${ip_hits}" ]]; then
        echo "  Private IP matches:"
        printf '%s\n' "${ip_hits}" | sed 's/^/    /'
      fi
      if [[ -n "${path_hits}" ]]; then
        echo "  Local path matches:"
        printf '%s\n' "${path_hits}" | sed 's/^/    /'
      fi
    fi
  fi
}

if [[ "${MODE}" == "staged" ]]; then
  tmp_file=$(mktemp)
  trap 'rm -f "${tmp_file}"' EXIT
  while IFS= read -r -d '' file; do
    if should_skip_file "${file}"; then
      continue
    fi
    # Skip deleted files and submodule entries.
    if ! git cat-file -e ":${file}" 2>/dev/null; then
      continue
    fi
    git show ":${file}" > "${tmp_file}"
    scan_file "${tmp_file}" "${file} (staged)"
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
elif [[ "${MODE}" == "changed" ]]; then
  while IFS= read -r -d '' file; do
    if should_skip_file "${file}"; then
      continue
    fi
    if [[ ! -f "${file}" ]]; then
      continue
    fi
    scan_file "${file}" "${file} (changed against ${BASE_REF})"
  done < <(git diff --name-only --diff-filter=ACMR -z "${BASE_REF}...HEAD")
else
  while IFS= read -r -d '' file; do
    if should_skip_file "${file}"; then
      continue
    fi
    if [[ ! -f "${file}" ]]; then
      continue
    fi
    scan_file "${file}" "${file}"
  done < <(git ls-files -z)
fi

if [[ "${has_errors}" -ne 0 ]]; then
  echo ""
  echo "Commit blocked: remove machine-local paths/private IPs or replace with placeholders."
  echo "Use placeholders like <abs-path-to-repo-root> and bolt://<neo4j-host-or-ip>:7688."
  exit 1
fi

echo "Sensitive literal check passed (${MODE})."
