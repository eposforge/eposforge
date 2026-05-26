#!/usr/bin/env bash
# bulk-rebuild.sh — full-corpus cognee-sync rebuild for eposforge
#
# Re-adds every *.md and *.ttl file tracked by git into Cognee.
# Use after a KG wipe (Ladybug stale-lock recovery) or when the graph
# needs to be rebuilt from scratch.
#
# Usage:
#   bash instance/installed/06-spec-graph/cognee/scripts/bulk-rebuild.sh [--dry-run]
#
# What this does:
#   1. Collects all *.md and *.ttl files tracked by git (repo root).
#   2. Wipes the cognee-sync state DB so every file is staged as new.
#   3. Runs cognee-sync --added on the full file list via Azure AI Foundry.
#
# Prerequisites:
#   - epos-secrets on PATH (or at instance/installed/12-secrets-key-management/bin/)
#   - dkr-cgnee-api container running and healthy
#   - uv available
#   - Age key authorised for the sops-age vault
#
# Token budget: a full 97-file corpus rebuild costs roughly 180K–200K tokens
# (embeddings only; LLM completion tokens are tracked separately). Check
# instance/.audit/inference-budget-counters.json before running.
#
# Bulk cognify note: the first cognify pass on 80+ docs may produce ~10
# SQLite contention errors. That is expected. Re-run this script after the
# first pass completes — the second pass picks up all missed docs cleanly.
# If the second pass also hits lock errors, restart dkr-cgnee-api first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"
SYNC_DIR="${REPO_ROOT}/instance/installed/06-spec-graph/cognee/sync"
STATE_DB="${SYNC_DIR}/.cognee-state.db"

# Locate epos-secrets: prefer PATH, fall back to known location
if command -v epos-secrets >/dev/null 2>&1; then
  SECRETS_BIN="epos-secrets"
else
  SECRETS_BIN="${REPO_ROOT}/instance/installed/12-secrets-key-management/bin/epos-secrets"
fi

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

# Collect all tracked *.md and *.ttl files
mapfile -t FILES < <(
  cd "$REPO_ROOT" &&
  git ls-files '*.md' '*.ttl' |
  sed "s|^|${REPO_ROOT}/|"
)

echo "bulk-rebuild: ${#FILES[@]} files staged from ${REPO_ROOT}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run: would run cognee-sync --added on ${#FILES[@]} files"
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
    --added "${FILES[@]}"

echo "bulk-rebuild: done — commit updated .cognee-state.db to source"
