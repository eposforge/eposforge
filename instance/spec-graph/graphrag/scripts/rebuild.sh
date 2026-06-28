#!/usr/bin/env bash
# rebuild.sh — Full nuke-and-reproject of the Spec Graph using GraphRAG.
#
# This is the GraphRAG adapter's rebuild entrypoint. For the default
# Cognee incremental sync path, use cognee-sync:
#   cd instance/spec-graph/cognee/sync
#   epos-secrets uv run cognee-sync --added/--modified/--deleted <files>
#
# Required environment variables:
#   ANTHROPIC_API_KEY — Anthropic API key (claude-sonnet-4-6)
#   NEO4J_URI         — Neo4j bolt URI (default: bolt://localhost:7688)
#   NEO4J_USERNAME    — Neo4j username (default: neo4j)
#   NEO4J_PASSWORD    — Neo4j password
#
# Recommended invocation (secrets resolved automatically):
#   python instance/secrets-key-management/bin/epos-secrets -- bash instance/spec-graph/graphrag/scripts/rebuild.sh
#
# Legacy invocation (manual env export):
#   ANTHROPIC_API_KEY=xxx NEO4J_PASSWORD=zzz bash instance/spec-graph/graphrag/scripts/rebuild.sh
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT is five levels above graphrag/scripts/
REPO_ROOT="$(cd "${SCRIPTS_DIR}/../../../../.." && pwd)"

export NEO4J_URI="${NEO4J_URI:-bolt://localhost:7688}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-neo4j}"

if [[ -n "${1:-}" ]]; then
  echo "ERROR: Unknown argument '${1:-}'. This script takes no arguments." >&2
  exit 1
fi

if [[ -z "${NEO4J_PASSWORD:-}" ]]; then
  echo "ERROR: NEO4J_PASSWORD is not set." >&2
  exit 1
fi

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  GRAPHRAG_PYTHON="${REPO_ROOT}/instance/spec-graph/graphrag/.venv/Scripts/python"
else
  GRAPHRAG_PYTHON="${REPO_ROOT}/instance/spec-graph/graphrag/.venv/bin/python"
fi

if [[ ! -f "${GRAPHRAG_PYTHON}" ]]; then
  echo "ERROR: GraphRAG venv not found. Expected: $(dirname "${GRAPHRAG_PYTHON}")/../.venv" >&2
  echo "Run: cd instance/spec-graph/graphrag && python -m venv .venv && .venv/bin/pip install 'graphrag==3.0.9' neo4j pandas pyarrow" >&2
  exit 1
fi

GRAPHRAG_OUTPUT_DIR="${REPO_ROOT}/instance/spec-graph/graphrag/output"
GRAPHRAG_CACHE_DIR="${REPO_ROOT}/instance/spec-graph/graphrag/cache"

echo "==> Starting GraphRAG Spec Graph rebuild"
echo "    Target: Neo4j (${NEO4J_URI})"
echo ""

echo "==> Wiping Neo4j graph..."
"${GRAPHRAG_PYTHON}" - <<'PYEOF'
import os
from neo4j import GraphDatabase

uri = os.environ["NEO4J_URI"]
username = os.environ["NEO4J_USERNAME"]
password = os.environ["NEO4J_PASSWORD"]

driver = GraphDatabase.driver(uri, auth=(username, password))
with driver.session() as session:
    session.run("MATCH (n) DETACH DELETE n")
driver.close()
print("Neo4j graph cleared.")
PYEOF

echo "==> Removing GraphRAG generated artifacts..."
rm -rf "${GRAPHRAG_OUTPUT_DIR}" "${GRAPHRAG_CACHE_DIR}"
mkdir -p "${GRAPHRAG_OUTPUT_DIR}"

bash "${SCRIPTS_DIR}/index.sh"
echo ""
bash "${SCRIPTS_DIR}/import.sh"

echo ""
echo "==> GraphRAG Spec Graph rebuild complete."

