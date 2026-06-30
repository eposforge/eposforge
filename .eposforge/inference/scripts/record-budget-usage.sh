#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  record-budget-usage.sh \
    --repo-key <repo-key> \
    --consumed-tokens <int>=0
EOF
}

repo_key=""
consumed_tokens=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-key) repo_key="${2:-}"; shift 2 ;;
    --consumed-tokens) consumed_tokens="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$repo_key" || -z "$consumed_tokens" ]]; then
  usage
  exit 2
fi

if [[ ! "$consumed_tokens" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --consumed-tokens must be a non-negative integer" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
counters_path="${INFERENCE_BUDGET_COUNTERS:-${repo_root}/.eposforge/.audit/inference-budget-counters.json}"

python3 - "$counters_path" "$repo_key" "$consumed_tokens" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
repo_key = sys.argv[2]
consumed = int(sys.argv[3])

path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid counter JSON: {exc}")
else:
    data = {"schema_version": "0.1.0", "repo_counters": {}}

if not isinstance(data, dict):
    data = {"schema_version": "0.1.0", "repo_counters": {}}

repo_counters = data.setdefault("repo_counters", {})
if not isinstance(repo_counters, dict):
    repo_counters = {}
    data["repo_counters"] = repo_counters

counter = repo_counters.setdefault(repo_key, {})
if not isinstance(counter, dict):
    counter = {}
    repo_counters[repo_key] = counter

used = counter.get("used_tokens", 0)
if not isinstance(used, int) or used < 0:
    used = 0

counter["used_tokens"] = used + consumed

path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"ok: repo_key={repo_key} used_tokens={counter['used_tokens']}")
PY
