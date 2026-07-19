#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  emit-token-usage-event.sh \
    --repo <repo> \
    --dataset <dataset> \
    --phase <extract|embed|cognify> \
    --model <model> \
    --prompt-tokens <int>=0 \
    --completion-tokens <int>=0 \
    --total-tokens <int>=0 \
    --latency-ms <int>=0
EOF
}

repo=""
dataset=""
phase=""
model=""
prompt_tokens=""
completion_tokens=""
total_tokens=""
latency_ms=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --dataset) dataset="${2:-}"; shift 2 ;;
    --phase) phase="${2:-}"; shift 2 ;;
    --model) model="${2:-}"; shift 2 ;;
    --prompt-tokens) prompt_tokens="${2:-}"; shift 2 ;;
    --completion-tokens) completion_tokens="${2:-}"; shift 2 ;;
    --total-tokens) total_tokens="${2:-}"; shift 2 ;;
    --latency-ms) latency_ms="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$repo" || -z "$dataset" || -z "$phase" || -z "$model" || -z "$prompt_tokens" || -z "$completion_tokens" || -z "$total_tokens" || -z "$latency_ms" ]]; then
  usage
  exit 2
fi

if [[ "$phase" != "extract" && "$phase" != "embed" && "$phase" != "cognify" ]]; then
  echo "ERROR: --phase must be one of: extract, embed, cognify" >&2
  exit 2
fi

is_nonnegative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

for n in "$prompt_tokens" "$completion_tokens" "$total_tokens" "$latency_ms"; do
  if ! is_nonnegative_int "$n"; then
    echo "ERROR: numeric values must be non-negative integers" >&2
    exit 2
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
emit_script="${repo_root}/.eposforge/audit-observability/jsonl-event-sink/scripts/emit-event.sh"

if [[ ! -x "$emit_script" ]]; then
  echo "ERROR: missing or non-executable sink emitter: $emit_script" >&2
  exit 1
fi

payload="$(python3 - "$repo" "$dataset" "$phase" "$model" "$prompt_tokens" "$completion_tokens" "$total_tokens" "$latency_ms" <<'PY'
import json
import sys

record = {
    "component": "inference",
    "adapter": "token-usage-emitter",
    "repo": sys.argv[1],
    "dataset": sys.argv[2],
    "phase": sys.argv[3],
    "model": sys.argv[4],
    "prompt_tokens": int(sys.argv[5]),
    "completion_tokens": int(sys.argv[6]),
    "total_tokens": int(sys.argv[7]),
    "latency_ms": int(sys.argv[8]),
}
print(json.dumps(record, separators=(",", ":")))
PY
)"

"$emit_script" adapter.invoked "$payload"
