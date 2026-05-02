#!/usr/bin/env bash
# spec-graph-rebuild.sh — Full nuke-and-reproject: GraphRAG index + Neo4j import.
#
# This is the standard maintenance command. Run it after any significant
# batch of Markdown changes. Per the Spec Graph component contract,
# nuke-and-reproject is the rebuild model; there is no incremental update.
#
# Required environment variables:
#   ANTHROPIC_API_KEY — Anthropic API key (claude-sonnet-4-6)
#   OPENAI_API_KEY    — OpenAI API key (text-embedding-3-small)
#   NEO4J_URI         — Neo4j bolt URI (default: bolt://localhost:7687)
#   NEO4J_USERNAME    — Neo4j username (default: neo4j)
#   NEO4J_PASSWORD    — Neo4j password
#
# Usage:
#   ANTHROPIC_API_KEY=xxx OPENAI_API_KEY=yyy NEO4J_PASSWORD=zzz bash instance/scripts/spec-graph-rebuild.sh [--cognee]
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"

# Apply defaults for optional env vars
export NEO4J_URI="${NEO4J_URI:-bolt://localhost:7687}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-neo4j}"

USE_COGNEE=false
if [[ "${1:-}" == "--cognee" ]]; then
  USE_COGNEE=true
fi

echo "==> Starting full Spec Graph rebuild"
if [ "$USE_COGNEE" = true ]; then
  echo "    Engine: Cognee (Ontology-Grounded Extraction)"
else
  echo "    Engine: Microsoft GraphRAG"
fi
echo "    Target: Neo4j (${NEO4J_URI})"
echo ""

if [ "$USE_COGNEE" = true ]; then
  VENV="${REPO_ROOT}/installed/06-spec-graph/cognee/.venv"
  # Use Windows path for python if on Windows, else standard
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    PYTHON="${VENV}/Scripts/python"
  else
    PYTHON="${VENV}/bin/python"
  fi
  
  if [[ ! -f "${PYTHON}" ]]; then
    echo "ERROR: Cognee venv not found at ${VENV}. Run: cd instance/installed/06-spec-graph/cognee && python -m venv .venv && pip install cognee neo4j pandas pyarrow" >&2
    exit 1
  fi
  
  echo "==> Running Cognee indexing..."
  "${PYTHON}" "${SCRIPTS_DIR}/spec-graph-cognee.py"
else
  bash "${SCRIPTS_DIR}/spec-graph-index.sh"
  echo ""
  bash "${SCRIPTS_DIR}/spec-graph-import.sh"
fi

echo ""
echo "==> Spec Graph rebuild complete."
