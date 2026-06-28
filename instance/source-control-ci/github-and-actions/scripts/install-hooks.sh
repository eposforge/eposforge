#!/usr/bin/env bash
# install-hooks.sh — Install EposForge Git hooks into the repo's hooks dir
# (portable across normal clones and worktrees used by polecat/agent clones).
#
# Discovers per-component hook fragments at:
#   instance/<component>/scripts/hooks/<git-hook-name>
#   instance/<component>/<adapter>/scripts/hooks/<git-hook-name>
#
# For each hook name that has at least one fragment, writes a dispatcher into
# .git/hooks/<git-hook-name> that runs every matching fragment in order.
#
# Cross-host: pure bash + git rev-parse — runs on Linux (srv-docker-hp) and on
# Windows via Git Bash (ws-dev-1). Re-runnable; refuses to overwrite a hook
# that wasn't placed by this script.
#
# Usage (run once per clone, per host):
#   bash instance/source-control-ci/github-and-actions/scripts/install-hooks.sh
#
# Optional:
#   --check     Exit 1 if installed dispatchers are out of sync with discovered
#               fragments. Does not write anything.
#   --uninstall Remove dispatchers installed by this script.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALLED_ROOT="${REPO_ROOT}/instance"  # flat layout (component dirs directly under instance/)
# Use --git-path for portability: works in normal clones (.git dir) and in
# git-worktrees (as used by polecat/agent runtimes) where hooks live under the
# common git dir.
HOOKS_DIR="$(git rev-parse --git-path hooks)"
MARKER="# managed-by: install-hooks.sh (eposforge)"

MODE="install"
case "${1:-}" in
  --check)     MODE="check" ;;
  --uninstall) MODE="uninstall" ;;
  "")          ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

# All valid Git hook names (per githooks(5)). The composer only treats files
# named exactly one of these as fragments; anything else under scripts/hooks/
# is ignored (e.g. README.md, helper scripts).
GIT_HOOK_NAMES=(
  applypatch-msg
  pre-applypatch
  post-applypatch
  pre-commit
  pre-merge-commit
  prepare-commit-msg
  commit-msg
  post-commit
  pre-rebase
  post-checkout
  post-merge
  pre-push
  pre-receive
  update
  proc-receive
  post-receive
  post-update
  reference-transaction
  push-to-checkout
  pre-auto-gc
  post-rewrite
  sendemail-validate
  fsmonitor-watchman
  p4-changelist
  p4-prepare-changelist
  p4-post-changelist
  p4-pre-submit
  post-index-change
)

is_git_hook_name() {
  local name="$1"
  for valid in "${GIT_HOOK_NAMES[@]}"; do
    [ "$name" = "$valid" ] && return 0
  done
  return 1
}

# Print discovered fragments (one per line), sorted by hook name then path.
discover_fragments() {
  find "$INSTALLED_ROOT" \
       -mindepth 4 -maxdepth 6 \
       -type f \
       -path '*/scripts/hooks/*' \
       2>/dev/null \
  | while IFS= read -r f; do
      name="$(basename "$f")"
      if is_git_hook_name "$name"; then
        printf '%s\t%s\n' "$name" "$f"
      fi
    done \
  | sort
}

# Dispatcher body for a given hook name. Stays small so the dispatcher remains
# diffable and trivially auditable on either host.
render_dispatcher() {
  cat <<'DISPATCHER'
#!/usr/bin/env bash
# managed-by: install-hooks.sh (eposforge)
# DO NOT EDIT — regenerate via:
#   bash instance/source-control-ci/github-and-actions/scripts/install-hooks.sh
#
# Runs every per-component fragment named <hook-name> under
# instance/*/scripts/hooks/ and instance/*/*/scripts/hooks/.
# All fragments run even if an earlier one fails; the dispatcher exits with the
# highest non-zero status seen so blocking hooks still block.
set -u
hook_name="$(basename "$0")"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$repo_root" ] || { echo "install-hooks dispatcher: not in a git repo" >&2; exit 1; }
shopt -s nullglob
status=0
for fragment in \
  "$repo_root"/instance/*/scripts/hooks/"$hook_name" \
  "$repo_root"/instance/*/*/scripts/hooks/"$hook_name"; do
  if [ -x "$fragment" ]; then
    "$fragment" "$@"
  else
    bash "$fragment" "$@"
  fi
  rc=$?
  if [ "$rc" -ne 0 ] && [ "$status" -eq 0 ]; then
    status="$rc"
  fi
done
exit "$status"
DISPATCHER
}

# Hook names that have at least one fragment.
discovered_names() {
  discover_fragments | awk -F'\t' '{print $1}' | uniq
}

# Hook files in the hooks dir that carry our marker line.
managed_installed_names() {
  [ -d "$HOOKS_DIR" ] || return 0
  for f in "$HOOKS_DIR"/*; do
    [ -f "$f" ] || continue
    if grep -qF "$MARKER" "$f" 2>/dev/null; then
      basename "$f"
    fi
  done
}

install_one() {
  local name="$1"
  local target="${HOOKS_DIR}/${name}"

  if [ -e "$target" ] && ! grep -qF "$MARKER" "$target" 2>/dev/null; then
    echo "  SKIP  ${name} — ${target} exists and is not managed by this script" >&2
    return 1
  fi

  render_dispatcher > "${target}.tmp"
  chmod +x "${target}.tmp"
  mv "${target}.tmp" "$target"
  echo "  install  ${name}"
}

uninstall_one() {
  local name="$1"
  local target="${HOOKS_DIR}/${name}"
  if [ -f "$target" ] && grep -qF "$MARKER" "$target" 2>/dev/null; then
    rm -f "$target"
    echo "  remove   ${name}"
  fi
}

check_one() {
  local name="$1"
  local target="${HOOKS_DIR}/${name}"
  if [ ! -f "$target" ]; then
    echo "  MISSING  ${name}"
    return 1
  fi
  if ! grep -qF "$MARKER" "$target" 2>/dev/null; then
    echo "  FOREIGN  ${name} (exists but not managed)"
    return 1
  fi
  local expected
  expected="$(render_dispatcher)"
  if [ "$expected" != "$(cat "$target")" ]; then
    echo "  STALE    ${name} (dispatcher body has drifted)"
    return 1
  fi
  echo "  ok       ${name}"
  return 0
}

mkdir -p "$HOOKS_DIR"
mapfile -t discovered < <(discovered_names)
mapfile -t installed  < <(managed_installed_names)

case "$MODE" in
  install)
    echo "==> Installing EposForge hook dispatchers"
    if [ "${#discovered[@]}" -eq 0 ]; then
      echo "  (no hook fragments found under ${INSTALLED_ROOT})"
    fi
    for name in "${discovered[@]}"; do
      install_one "$name" || true
    done
    # Remove dispatchers for hook names that no longer have fragments.
    for name in "${installed[@]}"; do
      keep=0
      for d in "${discovered[@]}"; do
        [ "$d" = "$name" ] && { keep=1; break; }
      done
      [ "$keep" -eq 0 ] && uninstall_one "$name"
    done
    echo "==> Done. Fragments installed by component:"
    discover_fragments | awk -F'\t' \
      '{ sub(/^.*\/instance\//, "instance/", $2); printf "  %s\t%s\n", $1, $2 }'
    ;;
  check)
    echo "==> Checking EposForge hook dispatchers"
    fail=0
    for name in "${discovered[@]}"; do
      check_one "$name" || fail=1
    done
    for name in "${installed[@]}"; do
      keep=0
      for d in "${discovered[@]}"; do
        [ "$d" = "$name" ] && { keep=1; break; }
      done
      if [ "$keep" -eq 0 ]; then
        echo "  ORPHAN   ${name} (installed but no fragments exist)"
        fail=1
      fi
    done
    [ "$fail" -eq 0 ] || exit 1
    ;;
  uninstall)
    echo "==> Removing EposForge hook dispatchers"
    for name in "${installed[@]}"; do
      uninstall_one "$name"
    done
    ;;
esac
