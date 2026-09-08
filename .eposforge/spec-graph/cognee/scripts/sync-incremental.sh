#!/usr/bin/env bash
# vehicle-class: in-repo-pipeline
# sync-incremental.sh — diff-driven incremental Cognee sync (EF-091)
#
# Computes the *.md/*.ttl files added, modified and deleted between a base
# commit and HEAD, excludes the ontology anchor (it is never a corpus
# document) and raw backlog items (EF-057 — they live in the independent
# file-based backlog graph), and dispatches cognee-sync with the resulting
# --added/--modified/--deleted lists.
#
# Extracted from skills/update-spec-graph/SKILL.md (EF-091, Standard 15
# requirement 9): the incremental-vs-full *choice* stays judgment in the
# skill; this script is the known recipe for actually running the
# incremental path once that choice is made.
#
# Usage:
#   bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/spec-graph/cognee/scripts/sync-incremental.sh" <base-commit> [cognee-sync args...]
#
# <base-commit> = the last commit whose changes are already reflected in the
# KG (e.g. the commit recorded the last time this script, or the manual
# recipe it replaces, ran successfully). Extra arguments (e.g. --dry-run)
# are forwarded verbatim to cognee-sync.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

BASE="${1:?usage: sync-incremental.sh <base-commit> [cognee-sync args...]}"
shift
EXTRA_ARGS=("$@")

ONTOLOGY_TTL='00-vision/01-ontology.ttl'
EXCLUDE_PATHS_RE='(^|/)(backlog/|\.eposforge/backlog/|plans/)'

ADDED=$(git diff --name-only --diff-filter=A "${BASE}..HEAD" -- '*.md' '*.ttl' | grep -vxF "${ONTOLOGY_TTL}" | grep -vE "${EXCLUDE_PATHS_RE}" || true)
MODIFIED=$(git diff --name-only --diff-filter=M "${BASE}..HEAD" -- '*.md' '*.ttl' | grep -vxF "${ONTOLOGY_TTL}" | grep -vE "${EXCLUDE_PATHS_RE}" || true)
DELETED=$(git diff --name-only --diff-filter=D "${BASE}..HEAD" -- '*.md' '*.ttl' | grep -vxF "${ONTOLOGY_TTL}" | grep -vE "${EXCLUDE_PATHS_RE}" || true)

if [[ -z "${ADDED}" && -z "${MODIFIED}" && -z "${DELETED}" ]]; then
  echo "sync-incremental: no eligible *.md/*.ttl changes between ${BASE} and HEAD"
  exit 0
fi

cd "${REPO_ROOT}/.eposforge/spec-graph/cognee/sync"
epos-secrets uv run cognee-sync --ontology-key "${COGNEE_ONTOLOGY_KEY:-eposforge}" \
    "${EXTRA_ARGS[@]}" \
    ${ADDED:+--added ${ADDED}} \
    ${MODIFIED:+--modified ${MODIFIED}} \
    ${DELETED:+--deleted ${DELETED}}
