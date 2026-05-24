#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  check-budget-gate.sh \
    --repo-key <repo-key> \
    --requested-tokens <int>=0 \
    --model <model>

Behavior:
  - Reads budget policy from INFERENCE_BUDGET_CONFIG or default policy file.
  - Reads persistent counters from INFERENCE_BUDGET_COUNTERS or default
    instance/.audit location.
  - Emits JSON with decision: allow | degrade | deny.
  - Exit code: 0 for allow/degrade, 4 for deny.
EOF
}

repo_key=""
requested_tokens=""
model=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-key) repo_key="${2:-}"; shift 2 ;;
    --requested-tokens) requested_tokens="${2:-}"; shift 2 ;;
    --model) model="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$repo_key" || -z "$requested_tokens" || -z "$model" ]]; then
  usage
  exit 2
fi

if [[ ! "$requested_tokens" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --requested-tokens must be a non-negative integer" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
config_path="${INFERENCE_BUDGET_CONFIG:-${repo_root}/instance/installed/10-inference/budget-policy.json}"
counters_path="${INFERENCE_BUDGET_COUNTERS:-${repo_root}/instance/.audit/inference-budget-counters.json}"

set +e
result_json="$(python3 - "$config_path" "$counters_path" "$repo_key" "$requested_tokens" "$model" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
counters_path = pathlib.Path(sys.argv[2])
repo_key = sys.argv[3]
requested = int(sys.argv[4])
model = sys.argv[5]

try:
    config = json.loads(config_path.read_text(encoding="utf-8"))
except FileNotFoundError:
    raise SystemExit(f"ERROR: budget config not found: {config_path}")
except json.JSONDecodeError as exc:
    raise SystemExit(f"ERROR: invalid budget config JSON: {exc}")

if counters_path.exists():
    try:
        counters = json.loads(counters_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid counter JSON: {exc}")
else:
    counters = {"schema_version": "0.1.0", "repo_counters": {}}

if not isinstance(counters, dict):
    counters = {"schema_version": "0.1.0", "repo_counters": {}}

repo_budgets = config.get("repo_budgets", {})
policy = repo_budgets.get(repo_key)
if not isinstance(policy, dict):
    decision = {
        "decision": "deny",
        "repo_key": repo_key,
        "reason": "no budget policy for repo key",
        "requested_tokens": requested,
        "model": model,
    }
    print(json.dumps(decision))
    raise SystemExit(4)

limit_tokens = policy.get("limit_tokens")
if not isinstance(limit_tokens, int) or limit_tokens < 0:
    raise SystemExit("ERROR: policy limit_tokens must be a non-negative integer")

repo_counters = counters.get("repo_counters", {})
counter = repo_counters.get(repo_key, {}) if isinstance(repo_counters, dict) else {}
used_tokens = counter.get("used_tokens", 0)
if not isinstance(used_tokens, int) or used_tokens < 0:
    used_tokens = 0

remaining = max(limit_tokens - used_tokens, 0)
degrade_model = policy.get("degrade_model", "")

if requested <= remaining:
    decision = {
        "decision": "allow",
        "repo_key": repo_key,
        "requested_tokens": requested,
        "used_tokens": used_tokens,
        "remaining_tokens": remaining,
        "limit_tokens": limit_tokens,
        "model": model,
    }
    print(json.dumps(decision))
    raise SystemExit(0)

if isinstance(degrade_model, str) and degrade_model and degrade_model != model and remaining > 0:
    decision = {
        "decision": "degrade",
        "repo_key": repo_key,
        "requested_tokens": requested,
        "used_tokens": used_tokens,
        "remaining_tokens": remaining,
        "limit_tokens": limit_tokens,
        "model": model,
        "recommended_model": degrade_model,
        "reason": "requested tokens exceed remaining budget",
    }
    print(json.dumps(decision))
    raise SystemExit(0)

decision = {
    "decision": "deny",
    "repo_key": repo_key,
    "requested_tokens": requested,
    "used_tokens": used_tokens,
    "remaining_tokens": remaining,
    "limit_tokens": limit_tokens,
    "model": model,
    "reason": "budget exhausted",
}
print(json.dumps(decision))
raise SystemExit(4)
PY
)"
rc=$?
set -e
echo "$result_json"
exit "$rc"
