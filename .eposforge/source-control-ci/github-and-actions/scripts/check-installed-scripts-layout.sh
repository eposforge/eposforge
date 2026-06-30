#!/usr/bin/env bash
# check-installed-scripts-layout.sh — Enforce the adapter-script placement rule.
#
# RULE: scripts owned by an installed adapter (hooks, runners, helpers) must live
# under.eposforge/<component>/scripts/ (or .../<adapter>/scripts/).
# The flat.eposforge/scripts/ directory is not permitted.
#
# Invoked from:
#   * pre-commit hook fragment at
#    .eposforge/source-control-ci/github-and-actions/scripts/hooks/pre-commit
#   * CI workflow .github/workflows/installed-scripts-layout.yml
#
# Cross-host: runs on Linux (srv-docker-hp) and Windows Git Bash (ws-dev-1).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
FORBIDDEN_DIR="${REPO_ROOT}/.eposforge/scripts"

offenders=()
if [ -d "$FORBIDDEN_DIR" ]; then
  while IFS= read -r -d '' f; do
    offenders+=("${f#"$REPO_ROOT/"}")
  done < <(find "$FORBIDDEN_DIR" -type f -print0 2>/dev/null)
fi

if [ "${#offenders[@]}" -gt 0 ]; then
  cat >&2 <<'MSG'
ERROR: forbidden files under.eposforge/scripts/.

Adapter scripts (hooks, runners, helpers) must live under
 .eposforge/<component>/scripts/
or
 .eposforge/<component>/<adapter>/scripts/

The flat.eposforge/scripts/ directory is not permitted. See AGENTS.md
§Conventions and.eposforge/SPEC.md §"Script placement convention".

Offending files:
MSG
  for f in "${offenders[@]}"; do
    echo "  $f" >&2
  done
  exit 1
fi
exit 0
