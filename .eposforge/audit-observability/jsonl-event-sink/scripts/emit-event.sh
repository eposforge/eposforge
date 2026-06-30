#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <event_type> '<payload_json_object>'" >&2
  exit 2
fi

event_type="$1"
payload="$2"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
sink_path="${EPOS_AUDIT_SINK:-${repo_root}/.eposforge/.audit/events.jsonl}"

mkdir -p "$(dirname "${sink_path}")"

python3 - "$event_type" "$payload" "$sink_path" <<'PY'
import datetime
import json
import pathlib
import sys

event_type = sys.argv[1]
payload_raw = sys.argv[2]
sink_path = pathlib.Path(sys.argv[3])

allowed_types = {
    "adapter.invoked",
    "policy.decision",
    "artifact.produced",
    "secret.accessed",
    "error",
}

if event_type not in allowed_types:
    print(
        f"ERROR: unsupported event_type '{event_type}'. "
        f"Allowed: {', '.join(sorted(allowed_types))}",
        file=sys.stderr,
    )
    raise SystemExit(2)

try:
    payload = json.loads(payload_raw)
except json.JSONDecodeError as exc:
    print(f"ERROR: payload must be valid JSON: {exc}", file=sys.stderr)
    raise SystemExit(2)

if not isinstance(payload, dict):
    print("ERROR: payload must be a JSON object", file=sys.stderr)
    raise SystemExit(2)

record = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "event_type": event_type,
    "payload": payload,
}

with sink_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, sort_keys=True) + "\n")
    fh.flush()

print(f"ok: wrote {event_type} to {sink_path}")
PY
