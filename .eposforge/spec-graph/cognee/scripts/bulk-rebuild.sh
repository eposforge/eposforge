#!/usr/bin/env bash
# bulk-rebuild.sh — full-corpus cognee-sync rebuild for eposforge
#
# Re-adds every *.md and *.ttl file tracked by git into Cognee.
# Use after a KG wipe (Ladybug stale-lock recovery) or when the graph
# needs to be rebuilt from scratch.
#
# Usage:
#   bash.eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh [--dry-run]
#
# What this does:
#   1. Collects all *.md and *.ttl files tracked by git (repo root),
#      EXCLUDING the ontology TTL — it is the anchor, not a corpus document.
#   2. Wipes the cognee-sync state DB so every file is staged as new.
#   3. Uploads the ontology TTL as the '$ONTOLOGY_KEY' anchor and runs
#      cognee-sync --added on the full file list via Azure AI Foundry,
#      cognifying with ontologyKey=[$ONTOLOGY_KEY] so entities are anchored.
#
# Ontology changes: this script does NOT wipe the knowledge graph. Because
# cognee dedups on content hash, re-running over unchanged docs will not
# re-anchor them against a changed ontology. After editing the ontology,
# first perform the KG wipe (see.eposforge/spec-graph/cognee/MAINTENANCE.md
# "Recovery procedures") and THEN run this script.
#
# Prerequisites:
#   - epos-secrets on PATH (or at.eposforge/secrets-key-management/bin/)
#   - dkr-cgnee-api container running and healthy
#   - uv available
#   - Age key authorised for the sops-age vault
#
# Token budget: a full 97-file corpus rebuild costs roughly 180K–200K tokens
# (embeddings only; LLM completion tokens are tracked separately). Check
#.eposforge/.audit/inference-budget-counters.json before running.
#
# Bulk cognify note: the first cognify pass on 80+ docs may produce ~10
# SQLite contention errors. That is expected. Re-run this script after the
# first pass completes — the second pass picks up all missed docs cleanly.
# If the second pass also hits lock errors, restart dkr-cgnee-api first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
SYNC_DIR="${REPO_ROOT}/.eposforge/spec-graph/cognee/sync"
STATE_DB="${SYNC_DIR}/.cognee-state.db"
ONTOLOGY_KEY="${COGNEE_ONTOLOGY_KEY:-eposforge}"
ONTOLOGY_REL="00-vision/01-ontology.ttl"
ONTOLOGY_FILE="${REPO_ROOT}/${ONTOLOGY_REL}"

# Locate epos-secrets: prefer PATH, fall back to known location
if command -v epos-secrets >/dev/null 2>&1; then
  SECRETS_BIN="$(command -v epos-secrets)"
else
  SECRETS_BIN="${REPO_ROOT}/.eposforge/secrets-key-management/bin/epos-secrets"
fi

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

# Collect all tracked *.md and *.ttl files, excluding:
# - the ontology TTL (anchor, not corpus)
# - raw backlog items (per EF-057: main Spec Graph gets mechanics via ontology only;
#   raw EF- (or adopter-prefixed ID) item text stays in the independent file-based backlog graph)
mapfile -t FILES < <(
  cd "$REPO_ROOT" &&
  git ls-files '*.md' '*.ttl' |
  grep -vxF "$ONTOLOGY_REL" |
  grep -vE '(^|/)(backlog/|.eposforge/backlog/|plans/)' |
  sed "s|^|${REPO_ROOT}/|"
)

echo "bulk-rebuild: ${#FILES[@]} files staged from ${REPO_ROOT} (backlog/ + plans/ + ontology excluded)"
echo "bulk-rebuild: ontology anchor: ${ONTOLOGY_REL} (key=${ONTOLOGY_KEY})"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run: would upload ${ONTOLOGY_REL} as ontology key '${ONTOLOGY_KEY}'"
  echo "dry-run: would run cognee-sync --added on ${#FILES[@]} files"
  echo "dry-run: would cognify with ontologyKey=[${ONTOLOGY_KEY}]"
  echo "dry-run: would wipe state DB at ${STATE_DB}"
  exit 0
fi

# Wipe the state DB so cognee-sync treats every file as new
if [[ -f "$STATE_DB" ]]; then
  echo "bulk-rebuild: wiping state DB: ${STATE_DB}"
  rm -f "$STATE_DB"
fi

echo "bulk-rebuild: starting cognee-sync --added ..."

COGNEE_HTTP_TIMEOUT=3600 \
COGNEE_CHUNKS_PER_BATCH="${COGNEE_CHUNKS_PER_BATCH:-6}" \
AZURE_API_BASE=https://fp-llm-gateway.openai.azure.com/ \
AZURE_API_VERSION=2024-12-01-preview \
INFERENCE_PROVIDER=azure-foundry \
COGNEE_REQUIRE_AZURE_ROUTING=1 \
INFERENCE_BUDGET_REPO_KEY=eposforge \
COGNEE_TOKEN_USAGE_FILE=/mnt/raid-storage/docker-volume-mounts/cognee/data/token-usage.jsonl \
LLM_MODEL=azure/mdl-openai-gpt41mini-std-eus2-r1 \
EMBEDDING_MODEL=azure/mdl-openai-textembed3large-std-eus2-r1 \
python3 "$SECRETS_BIN" -- \
  uv run --directory "$SYNC_DIR" cognee-sync \
    --ontology-key "$ONTOLOGY_KEY" \
    --upload-ontology "$ONTOLOGY_FILE" \
    --added "${FILES[@]}"

# cognee/Ladybug does NOT checkpoint the WAL into the main graph file on close
# (verified: a graceful stop leaves data WAL-only, lost on any unclean restart).
# Force a checkpoint via the Cypher endpoint so the graph is durable on disk.
echo "bulk-rebuild: checkpointing WAL -> main graph file ..."
COGNEE_API="${COGNEE_API_URL:-http://127.0.0.1:18000}"
if curl -sf -X POST "${COGNEE_API}/api/v1/search" -H 'Content-Type: application/json' \
     -d '{"searchType":"CYPHER","query":"CHECKPOINT"}' >/dev/null; then
  node_count="$(curl -s -X POST "${COGNEE_API}/api/v1/search" -H 'Content-Type: application/json' \
     -d '{"searchType":"CYPHER","query":"MATCH (n) RETURN count(n) AS c"}' 2>/dev/null)"
  echo "bulk-rebuild: checkpoint issued; live graph node count = ${node_count}"
else
  echo "bulk-rebuild: WARNING — checkpoint call failed; graph may be WAL-only (not durable)." >&2
fi

echo "bulk-rebuild: done — commit updated .cognee-state.db to source"
