#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  validate-azure-routing-config.sh \
    --provider <anthropic|openai|azure-foundry> \
    --llm-model <model> \
    --embedding-model <model>

Notes:
  - For provider=azure-foundry, requires AZURE_API_BASE, AZURE_API_KEY,
    AZURE_API_VERSION in environment, and model names must begin with azure/.
EOF
}

provider=""
llm_model=""
embedding_model=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) provider="${2:-}"; shift 2 ;;
    --llm-model) llm_model="${2:-}"; shift 2 ;;
    --embedding-model) embedding_model="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$provider" || -z "$llm_model" || -z "$embedding_model" ]]; then
  usage
  exit 2
fi

case "$provider" in
  anthropic|openai|azure-foundry) ;;
  *)
    echo "ERROR: provider must be one of anthropic, openai, azure-foundry" >&2
    exit 2
    ;;
esac

if [[ "$provider" == "azure-foundry" ]]; then
  if [[ -z "${AZURE_API_BASE:-}" || -z "${AZURE_API_KEY:-}" || -z "${AZURE_API_VERSION:-}" ]]; then
    echo "ERROR: AZURE_API_BASE, AZURE_API_KEY, and AZURE_API_VERSION are required for provider=azure-foundry" >&2
    exit 2
  fi
  if [[ "$llm_model" != azure/* ]]; then
    echo "ERROR: --llm-model must start with azure/ when provider=azure-foundry" >&2
    exit 2
  fi
  if [[ "$embedding_model" != azure/* ]]; then
    echo "ERROR: --embedding-model must start with azure/ when provider=azure-foundry" >&2
    exit 2
  fi
fi

echo "ok: provider=$provider llm_model=$llm_model embedding_model=$embedding_model"
