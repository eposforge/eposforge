#!/usr/bin/env bash
# spec-graph-index.sh — Run GraphRAG indexing over EposForge Markdown docs.
#
# Reads all *.md files matched by installed/spec-graph/graphrag/settings.yaml (00-vision/,
# 01-architecture/, 02-roadmap/, 03-research/) and produces Parquet
# output in installed/spec-graph/graphrag/output/.
#
# Prerequisites:
#   - Python venv at installed/spec-graph/graphrag/.venv with graphrag installed
#   - ANTHROPIC_API_KEY and OPENAI_API_KEY environment variables set
#     (or GEMINI_API_KEY if using the Gemini alternative in settings.yaml)
#
# Usage:
#   bash.eposforge/spec-graph/graphrag/scripts/index.sh
#   ANTHROPIC_API_KEY=your-key OPENAI_API_KEY=your-key bash.eposforge/spec-graph/graphrag/scripts/index.sh
set -euo pipefail

GRAPHRAG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${GRAPHRAG_DIR}/.venv"
PYTHON="${VENV}/bin/python"

# Verify prerequisites
if [[ ! -d "${VENV}" ]]; then
  echo "ERROR: Python venv not found at ${VENV}" >&2
  echo "Run: cd.eposforge/spec-graph/graphrag && python -m venv .venv && source .venv/bin/activate && pip install graphrag" >&2
  exit 1
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY is not set." >&2
  echo "Export ANTHROPIC_API_KEY before running this script." >&2
  echo "(If using the Gemini alternative in settings.yaml, set GEMINI_API_KEY instead.)" >&2
  exit 1
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "ERROR: OPENAI_API_KEY is not set (required for embeddings)." >&2
  echo "Export OPENAI_API_KEY before running this script." >&2
  echo "(If using the Gemini alternative in settings.yaml, set GEMINI_API_KEY instead.)" >&2
  exit 1
fi

echo "==> GraphRAG indexing starting (root: ${GRAPHRAG_DIR})"
cd "${GRAPHRAG_DIR}"

"${PYTHON}" -m graphrag index --root .

# Clear the .needs-rebuild flag if it exists
rm -f "${GRAPHRAG_DIR}/../.needs-rebuild"

echo "==> Indexing complete. Parquet files in ${GRAPHRAG_DIR}/output/"
echo "    Run.eposforge/spec-graph/graphrag/scripts/import.sh to load into Neo4j."
