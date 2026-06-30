#!/usr/bin/env bash
set -euo pipefail

limit=20
event_type=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      limit="${2:-}"
      shift 2
      ;;
    --event-type)
      event_type="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--event-type <type>] [--limit <n>]" >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
sink_path="${EPOS_AUDIT_SINK:-${repo_root}/.eposforge/.audit/events.jsonl}"

python3 - "$sink_path" "$event_type" "$limit" <<'PY'
import json
import pathlib
import sys

sink_path = pathlib.Path(sys.argv[1])
event_type = sys.argv[2]

try:
    limit = int(sys.argv[3])
except ValueError:
    print("ERROR: --limit must be an integer", file=sys.stderr)
    raise SystemExit(2)

if limit < 1:
    print("ERROR: --limit must be >= 1", file=sys.stderr)
    raise SystemExit(2)

if not sink_path.exists():
    print(f"[]  # sink file not found: {sink_path}")
    raise SystemExit(0)

events = []
for line in sink_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    try:
        record = json.loads(line)
    except json.JSONDecodeError:
        continue
    if event_type and record.get("event_type") != event_type:
        continue
    events.append(record)

print(json.dumps(events[-limit:], indent=2))
PY
