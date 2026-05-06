#!/usr/bin/env bash
# Ingest the EposForge markdown corpus into Cognee using the running dual-container stack.
#
# This script uses the Cognee HTTP REST API — it does NOT exec Python inside the
# running API container.  Using docker-exec Python while the API server is running
# causes Ladybug embedded-graph DB lock conflicts.
#
# Target containers:
#   - dkr-cgnee-api (Cognee backend/API, must be running and healthy)
#
# Usage:
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --skip-prune
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke
#   bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke --max-files 8
#
# Prune behaviour:
#   By default (no --skip-prune), the script performs a full reset before ingest:
#     1. Stops dkr-cgnee-api and dkr-cgnee-mcp
#     2. Wipes ./data/cognee_system/databases/ using a temporary Alpine container
#     3. Restarts the stack and waits for healthy
#   This ensures a clean slate and avoids vector-dimension mismatches when
#   the embedding provider or model has changed since the last run.
#
# Requirements:
#   - docker and rsync on PATH
#   - dkr-cgnee-api is running and healthy (or will be after prune+restart)
#   - COGNEE_COMPOSE_DIR env var (default: /mnt/raid-storage/docker-volume-mounts/cognee)
#   - COGNEE_DATA_DIR env var (default: ${COGNEE_COMPOSE_DIR}/data/cognee_system)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"

API_CONTAINER="dkr-cgnee-api"
DATASET_NAME="eposforge"
CORPUS_HOST_DIR="$(mktemp -d /tmp/eposforge-corpus.XXXXXX)"
CORPUS_CONTAINER_DIR="/tmp/eposforge-corpus"
COGNEE_COMPOSE_DIR="${COGNEE_COMPOSE_DIR:-/mnt/raid-storage/docker-volume-mounts/cognee}"
COGNEE_DB_DIR="${COGNEE_DATA_DIR:-${COGNEE_COMPOSE_DIR}/data/cognee_system}"

SKIP_PRUNE=false
SKIP_PRUNE_SET=false
SMOKE=false
MAX_FILES=0
BATCH_SIZE=50   # max files per /api/v1/add POST

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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
api_curl() {
  # Run a curl command inside the API container (avoids publishing port 8000).
  # Usage: api_curl [curl-args...]
  docker exec "${API_CONTAINER}" sh -c "curl -s $*"
}

wait_healthy() {
  local container="$1"
  local max_wait="${2:-120}"
  local elapsed=0
  echo "    Waiting for ${container} to become healthy (max ${max_wait}s)..."
  while true; do
    local status
    status="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "missing")"
    if [[ "${status}" == "healthy" ]]; then
      echo "    ${container} is healthy."
      return 0
    fi
    if [[ "${elapsed}" -ge "${max_wait}" ]]; then
      echo "ERROR: ${container} did not become healthy within ${max_wait}s (status: ${status})." >&2
      return 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
for cmd in docker rsync; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: '${cmd}' is not available on PATH." >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Prune: stop stack, wipe databases, restart
# ---------------------------------------------------------------------------
if [[ "${SKIP_PRUNE}" == "false" ]]; then
  echo "==> Pruning: stopping Cognee stack and wiping databases..."
  (cd "${COGNEE_COMPOSE_DIR}" && docker compose stop dkr-cgnee-api dkr-cgnee-mcp 2>/dev/null) || true

  echo "    Wiping ${COGNEE_DB_DIR}/databases/ ..."
  docker run --rm \
    -v "${COGNEE_DB_DIR}:/cognee_system" \
    alpine sh -c "rm -rf /cognee_system/databases && mkdir /cognee_system/databases"

  echo "    Restarting stack..."
  (cd "${COGNEE_COMPOSE_DIR}" && docker compose up -d dkr-cgnee-api dkr-cgnee-mcp)
  wait_healthy "${API_CONTAINER}"
else
  # Verify the container is already running when skipping prune.
  if ! docker ps --format '{{.Names}}' | grep -qx "${API_CONTAINER}"; then
    echo "ERROR: Container '${API_CONTAINER}' is not running (required when --skip-prune is set)." >&2
    exit 1
  fi
  wait_healthy "${API_CONTAINER}"
fi

# ---------------------------------------------------------------------------
# Build corpus snapshot
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Copy corpus into container
# ---------------------------------------------------------------------------
echo "==> Copying corpus into ${API_CONTAINER}:${CORPUS_CONTAINER_DIR}"
docker exec "${API_CONTAINER}" sh -c "rm -rf '${CORPUS_CONTAINER_DIR}' && mkdir -p '${CORPUS_CONTAINER_DIR}'"
tar -C "${CORPUS_HOST_DIR}" -cf - . | docker exec -i "${API_CONTAINER}" tar -C "${CORPUS_CONTAINER_DIR}" -xf -

# ---------------------------------------------------------------------------
# Add: upload corpus via HTTP API in batches
# ---------------------------------------------------------------------------
echo "==> Uploading corpus to Cognee via POST /api/v1/add (dataset=${DATASET_NAME}, batch_size=${BATCH_SIZE})..."
mapfile -t all_files < <(docker exec "${API_CONTAINER}" find "${CORPUS_CONTAINER_DIR}" -type f \( -name '*.md' -o -name '*.ttl' \) | sort)
total="${#all_files[@]}"
batch_num=0
offset=0

while [[ "${offset}" -lt "${total}" ]]; do
  batch=("${all_files[@]:${offset}:${BATCH_SIZE}}")
  batch_num=$((batch_num + 1))
  batch_end=$((offset + ${#batch[@]}))
  echo "    Batch ${batch_num}: files ${offset+1}-${batch_end} of ${total}"

  # Build the -F args for this batch
  form_args="-F 'datasetName=${DATASET_NAME}'"
  for f in "${batch[@]}"; do
    form_args="${form_args} -F 'data=@${f}'"
  done

  add_resp=$(docker exec "${API_CONTAINER}" sh -c "curl -s -X POST http://localhost:8000/api/v1/add ${form_args}")
  add_status=$(echo "${add_resp}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('status','?'))" 2>/dev/null || echo "parse_error")

  if [[ "${add_status}" != "PipelineRunCompleted" ]]; then
    echo "ERROR: /api/v1/add batch ${batch_num} failed. Status: ${add_status}" >&2
    echo "Response: ${add_resp}" >&2
    exit 1
  fi
  echo "    Batch ${batch_num}: ADD_OK"
  offset=$((offset + ${#batch[@]}))
done

# ---------------------------------------------------------------------------
# Cognify: build knowledge graph
# ---------------------------------------------------------------------------
echo "==> Running cognify via POST /api/v1/cognify (dataset=${DATASET_NAME})..."
cog_resp=$(api_curl "-X POST http://localhost:8000/api/v1/cognify \
  -H 'Content-Type: application/json' \
  -d '{\"datasets\":[\"${DATASET_NAME}\"]}'")

# Response is a dict keyed by dataset_id; check every entry for status
cog_ok=$(echo "${cog_resp}" | python3 -c "
import sys, json
r = json.load(sys.stdin)
if isinstance(r, dict) and 'error' in r:
    print('error')
    raise SystemExit(1)
statuses = [v.get('status','?') for v in r.values()] if isinstance(r, dict) else [r.get('status','?')]
all_ok = all(s == 'PipelineRunCompleted' for s in statuses)
print('ok' if all_ok else 'error')
for s in statuses:
    print(' ', s, file=sys.stderr)
" 2>/dev/null || echo "parse_error")

if [[ "${cog_ok}" != "ok" ]]; then
  echo "ERROR: /api/v1/cognify failed." >&2
  echo "Response: ${cog_resp}" >&2
  exit 1
fi

echo "COGNIFY_OK"
echo "==> Ingestion complete. Validate: curl -fsS https://cognee-mcp.grace.lan/health"

