#!/usr/bin/env bash
# install-hooks.sh — Install eposforge Git hooks into .git/hooks/.
#
# Usage:
#   bash instance/scripts/hooks/install-hooks.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOKS_SRC="${REPO_ROOT}/instance/scripts/hooks"
HOOKS_DST="${REPO_ROOT}/.git/hooks"

install_hook() {
  local name="$1"
  local src="${HOOKS_SRC}/${name}"
  local dst="${HOOKS_DST}/${name}"

  if [[ -f "${dst}" && ! -L "${dst}" ]]; then
    echo "  WARNING: ${dst} already exists and is not a symlink. Skipping."
    return
  fi

  ln -sf "${src}" "${dst}"
  chmod +x "${src}"
  echo "  Installed: ${name} -> ${dst}"
}

echo "==> Installing Git hooks from ${HOOKS_SRC}"
install_hook post-commit
echo "==> Done."
