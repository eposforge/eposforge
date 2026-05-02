#!/usr/bin/env bash
# spec-graph-rebuild.sh — Full nuke-and-reproject with Cognee as default.
#
# This is the standard maintenance command. Run it after any significant
# batch of Markdown changes. Per the Spec Graph component contract,
# nuke-and-reproject is the rebuild model; there is no incremental update.
#
# Required environment variables:
#   ANTHROPIC_API_KEY — Anthropic API key (claude-sonnet-4-6)
#   NEO4J_URI         — Neo4j bolt URI (default: bolt://localhost:7688)
#   NEO4J_USERNAME    — Neo4j username (default: neo4j)
#   NEO4J_PASSWORD    — Neo4j password
#   COGNEE_VENV       — Optional: override Cognee venv path.
#                       On Windows (long-path disabled) use a short path:
#                       e.g. COGNEE_VENV=C:\cognee-venv
#
# Usage:
#   ANTHROPIC_API_KEY=xxx NEO4J_PASSWORD=zzz bash instance/scripts/spec-graph-rebuild.sh [--graphrag]
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"

# Apply defaults for optional env vars
export NEO4J_URI="${NEO4J_URI:-bolt://localhost:7688}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-neo4j}"

USE_GRAPHRAG=false
if [[ "${1:-}" == "--graphrag" ]]; then
  USE_GRAPHRAG=true
elif [[ -n "${1:-}" ]]; then
  echo "ERROR: Unknown flag '${1:-}'. Supported flags: --graphrag" >&2
  exit 1
fi

if [[ -z "${NEO4J_PASSWORD:-}" ]]; then
  echo "ERROR: NEO4J_PASSWORD is not set." >&2
  exit 1
fi

COGNEE_VENV="${COGNEE_VENV:-${REPO_ROOT}/installed/06-spec-graph/cognee/.venv}"
GRAPHRAG_VENV="${REPO_ROOT}/installed/06-spec-graph/graphrag/.venv"
GRAPHRAG_OUTPUT_DIR="${REPO_ROOT}/installed/06-spec-graph/graphrag/output"
GRAPHRAG_CACHE_DIR="${REPO_ROOT}/installed/06-spec-graph/graphrag/cache"

venv_python() {
  local venv="$1"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "${venv}/Scripts/python"
  else
    echo "${venv}/bin/python"
  fi
}

COGNEE_PYTHON="$(venv_python "${COGNEE_VENV}")"
GRAPHRAG_PYTHON="$(venv_python "${GRAPHRAG_VENV}")"

WIPE_PYTHON=""
if [[ -f "${COGNEE_PYTHON}" ]]; then
  WIPE_PYTHON="${COGNEE_PYTHON}"
elif [[ -f "${GRAPHRAG_PYTHON}" ]]; then
  WIPE_PYTHON="${GRAPHRAG_PYTHON}"
else
  echo "ERROR: No Python runtime found for Neo4j wipe. Expected one of:" >&2
  echo "  - ${COGNEE_PYTHON}" >&2
  echo "  - ${GRAPHRAG_PYTHON}" >&2
  exit 1
fi

echo "==> Starting full Spec Graph rebuild"
if [ "$USE_GRAPHRAG" = true ]; then
  echo "    Engine: Microsoft GraphRAG"
else
  echo "    Engine: Cognee (Ontology-Grounded Extraction)"
fi
echo "    Target: Neo4j (${NEO4J_URI})"
echo ""

echo "==> Wiping Neo4j graph projection state..."
"${WIPE_PYTHON}" - <<'PYEOF'
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

if [[ -f "${COGNEE_PYTHON}" ]]; then
  echo "==> Pruning Cognee state..."
  export COGNEE_ROOT_PATH="${REPO_ROOT}/installed/06-spec-graph/cognee/.cognee"
  "${COGNEE_PYTHON}" - <<'PYEOF'
import os
import cognee

cognee_root = os.environ["COGNEE_ROOT_PATH"]
cognee.config.system_root_directory = cognee_root

cognee.prune()
print("Cognee state pruned.")
PYEOF
else
  echo "==> WARNING: Cognee venv not found, skipping Cognee prune at ${COGNEE_VENV}"
fi

echo "==> Removing GraphRAG generated artifacts..."
rm -rf "${GRAPHRAG_OUTPUT_DIR}" "${GRAPHRAG_CACHE_DIR}"
mkdir -p "${GRAPHRAG_OUTPUT_DIR}"

if [ "$USE_GRAPHRAG" = true ]; then
  bash "${SCRIPTS_DIR}/spec-graph-index.sh"
  echo ""
  bash "${SCRIPTS_DIR}/spec-graph-import.sh"
else
  if [[ ! -f "${COGNEE_PYTHON}" ]]; then
    echo "ERROR: Cognee venv not found at ${COGNEE_VENV}. Run: cd instance/installed/06-spec-graph/cognee && python -m venv .venv && pip install cognee fastembed neo4j pandas pyarrow" >&2
    exit 1
  fi
  echo "==> Running Cognee indexing..."
  "${COGNEE_PYTHON}" "${SCRIPTS_DIR}/spec-graph-cognee.py"
fi

echo ""
echo "==> Spec Graph rebuild complete."
