#!/usr/bin/env bash
# install-hooks.sh — Install repository Git hooks into .git/hooks.
#
# Usage:
#   bash instance/scripts/hooks/install-hooks.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="${REPO_ROOT}/instance/scripts/hooks"
HOOKS_DST="${REPO_ROOT}/.git/hooks"

install_hook() {
  local name="$1"
  local src="${HOOKS_SRC}/${name}"
  local dst="${HOOKS_DST}/${name}"

  if [[ ! -f "${src}" ]]; then
    echo "ERROR: hook source not found: ${src}" >&2
    exit 1
  fi

  if [[ -f "${dst}" && ! -L "${dst}" ]]; then
    echo "WARNING: ${dst} exists and is not a symlink; skipping."
    return
  fi

  ln -sf "${src}" "${dst}"
  chmod +x "${src}"
  echo "Installed: ${name}"
}

echo "Installing Git hooks from ${HOOKS_SRC}"
install_hook pre-commit
install_hook post-commit
echo "Done."
