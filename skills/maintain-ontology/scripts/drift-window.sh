#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# drift-window.sh — print the last full KG rebuild commit and the markdown
# files changed since then. That rebuild — not the last TTL edit — is the
# drift window for maintain-ontology.
#
# Usage (from any cwd):
#   bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/skills/maintain-ontology/scripts/drift-window.sh"
#   bash .../drift-window.sh --repo <path>
#
# Resolution order for the rebuild commit:
#   1. .eposforge/spec-graph/cognee/sync/last-full-rebuild (commit=)
#   2. Infer from the cognee-state DB: majority synced_at UTC date, then the
#      git commit on that date that touched the state DB
#   Never fall back to `git log -- 00-vision/01-ontology.ttl`.
set -euo pipefail

REPO_ROOT=""
if [[ "${1:-}" == "--repo" ]]; then
  REPO_ROOT="${2:?--repo requires a path}"
elif [[ -n "${EPOSFORGE_HOME:-}" ]]; then
  REPO_ROOT="$EPOSFORGE_HOME"
else
  REPO_ROOT="$(git rev-parse --show-toplevel)"
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

STAMP="${REPO_ROOT}/.eposforge/spec-graph/cognee/sync/last-full-rebuild"
STATE_DB="${REPO_ROOT}/.eposforge/spec-graph/cognee/sync/.cognee-state.db"
STATE_REL=".eposforge/spec-graph/cognee/sync/.cognee-state.db"

rebuild=""
rebuild_date=""
source=""

if [[ -f "$STAMP" ]]; then
  rebuild="$(awk -F= '/^commit=/{print $2; exit}' "$STAMP")"
  rebuild_date="$(awk -F= '/^date=/{print $2; exit}' "$STAMP")"
  source="stamp"
fi

if [[ -z "$rebuild" ]]; then
  if [[ ! -f "$STATE_DB" ]]; then
    echo "ERROR: no last-full-rebuild stamp and no cognee-state DB at ${STATE_DB}" >&2
    echo "ERROR: do not use the last TTL edit as the drift window" >&2
    exit 2
  fi
  majority_date="$(python3 - "$STATE_DB" <<'PY'
import sqlite3, sys
from collections import Counter
con = sqlite3.connect(sys.argv[1])
try:
    dates = [r[0][:10] for r in con.execute("SELECT synced_at FROM tracked_files") if r[0]]
except sqlite3.Error as e:
    sys.stderr.write(f"ERROR: cannot read tracked_files: {e}\n")
    sys.exit(2)
if not dates:
    sys.stderr.write("ERROR: cognee-state DB has no tracked_files rows\n")
    sys.exit(2)
day, n = Counter(dates).most_common(1)[0]
print(day)
PY
)"
  rebuild="$(git -C "$REPO_ROOT" log --format='%H %ad' --date=short --no-show-signature -- "$STATE_REL" \
    | awk -v d="$majority_date" '$2 == d { print $1; exit }')"
  rebuild_date="$majority_date"
  source="state-db:${majority_date}"
fi

if [[ -z "$rebuild" ]]; then
  echo "ERROR: could not resolve last full KG rebuild commit" >&2
  echo "ERROR: do not use the last TTL edit as the drift window" >&2
  exit 2
fi

if ! git -C "$REPO_ROOT" cat-file -e "${rebuild}^{commit}" 2>/dev/null; then
  echo "ERROR: rebuild commit ${rebuild} is not in this repository" >&2
  exit 2
fi

ttl_last="$(git -C "$REPO_ROOT" log -1 --format=%H --no-show-signature -- 00-vision/01-ontology.ttl || true)"
echo "rebuild_commit=${rebuild}"
echo "rebuild_date=${rebuild_date}"
echo "source=${source}"
if [[ -n "$ttl_last" && "$ttl_last" != "$rebuild" ]]; then
  echo "ttl_last_commit=${ttl_last} (not the drift window)"
fi
echo "---"
git -C "$REPO_ROOT" diff --name-only "${rebuild}..HEAD" -- "*.md"
