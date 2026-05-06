#!/usr/bin/env bash
# Ingest the EposForge markdown corpus into Cognee using the running dual-container stack.
#
# Target containers:
#   - dkr-cgnee-api (Cognee backend/API)
#   - dkr-neo4j-01 (graph database)
#
# Usage:
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --skip-prune
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke --max-files 8

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"

API_CONTAINER="dkr-cgnee-api"
CORPUS_HOST_DIR="$(mktemp -d /tmp/eposforge-corpus.XXXXXX)"
CORPUS_CONTAINER_DIR="/tmp/eposforge-corpus"
SKIP_PRUNE=false
SKIP_PRUNE_SET=false
SMOKE=false
MAX_FILES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-prune)
      SKIP_PRUNE=true
      SKIP_PRUNE_SET=true
      shift
      ;;
    --smoke)
      SMOKE=true
      shift
      ;;
    --max-files)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --max-files requires a numeric value." >&2
        exit 1
      fi
      MAX_FILES="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument '$1'. Supported: --skip-prune, --smoke, --max-files <n>" >&2
      exit 1
      ;;
  esac
done

if ! [[ "${MAX_FILES}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --max-files must be a non-negative integer." >&2
  exit 1
fi

if [[ "${SMOKE}" == "true" ]]; then
  if [[ "${SKIP_PRUNE_SET}" == "false" ]]; then
    SKIP_PRUNE=true
  fi
  if [[ "${MAX_FILES}" == "0" ]]; then
    MAX_FILES=8
  fi
fi

cleanup() {
  rm -rf "${CORPUS_HOST_DIR}"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not available on PATH." >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: tar is not available on PATH." >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${API_CONTAINER}"; then
  echo "ERROR: Container '${API_CONTAINER}' is not running." >&2
  exit 1
fi

echo "==> Building markdown/ttl corpus snapshot from repo..."
search_roots=(
  "00-vision"
  "01-architecture"
  "02-roadmap"
  "03-research"
  "instance/installed"
  "instance/adrs"
)

for rel in "${search_roots[@]}"; do
  src="${REPO_ROOT}/${rel}"
  dst="${CORPUS_HOST_DIR}/${rel}"
  if [[ -d "${src}" ]]; then
    mkdir -p "${dst}"
    rsync -a --prune-empty-dirs \
      --include '*/' \
      --include '*.md' \
      --include '*.ttl' \
      --exclude '*' \
      "${src}/" "${dst}/"
  fi
done

doc_count="$(find "${CORPUS_HOST_DIR}" -type f \( -name '*.md' -o -name '*.ttl' \) | wc -l | tr -d ' ')"
echo "    Collected ${doc_count} source documents"
if [[ "${doc_count}" == "0" ]]; then
  echo "ERROR: No markdown/ttl corpus files found to ingest." >&2
  exit 1
fi

if [[ "${MAX_FILES}" -gt 0 ]]; then
  mapfile -t corpus_files < <(find "${CORPUS_HOST_DIR}" -type f \( -name '*.md' -o -name '*.ttl' \) | sort)
  total_files="${#corpus_files[@]}"
  if [[ "${total_files}" -gt "${MAX_FILES}" ]]; then
    for file_path in "${corpus_files[@]:${MAX_FILES}}"; do
      rm -f "${file_path}"
    done
      find "${CORPUS_HOST_DIR}" -mindepth 1 -type d -empty -delete
  fi
  doc_count="$(find "${CORPUS_HOST_DIR}" -type f \( -name '*.md' -o -name '*.ttl' \) | wc -l | tr -d ' ')"
  echo "    Limited corpus to ${doc_count} documents (max-files=${MAX_FILES})"
fi

if [[ "${SMOKE}" == "true" ]]; then
  echo "    Mode: smoke (skip-prune=${SKIP_PRUNE}, max-files=${MAX_FILES})"
else
  echo "    Mode: full"
fi

echo "==> Copying corpus into ${API_CONTAINER}:${CORPUS_CONTAINER_DIR}"
docker exec "${API_CONTAINER}" sh -lc "rm -rf '${CORPUS_CONTAINER_DIR}' && mkdir -p '${CORPUS_CONTAINER_DIR}'"
tar -C "${CORPUS_HOST_DIR}" -cf - . | docker exec -i "${API_CONTAINER}" tar -C "${CORPUS_CONTAINER_DIR}" -xf -

echo "==> Running Cognee ingestion inside ${API_CONTAINER}"
if [[ "${SKIP_PRUNE}" == "true" ]]; then
  PRUNE_FLAG="false"
else
  PRUNE_FLAG="true"
fi

docker exec "${API_CONTAINER}" python - <<PY
import asyncio
import cognee

CORPUS_DIR = "${CORPUS_CONTAINER_DIR}"
DO_PRUNE = ${PRUNE_FLAG}

async def run() -> None:
    if DO_PRUNE:
        print("Pruning existing Cognee state...")
        cognee.prune()

    print(f"Adding corpus from {CORPUS_DIR} ...")
    await cognee.add(CORPUS_DIR)

    print("Running cognify...")
    await cognee.cognify()

    print("Ingestion complete.")

asyncio.run(run())
PY

echo "==> Done. Validate health via: curl -fsS https://cognee-mcp.grace.lan/health"
