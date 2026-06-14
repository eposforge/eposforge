#!/usr/bin/env bash
set -euo pipefail

JSON=0
ROOTS_CLI=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON=1
      shift
      ;;
    --roots)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        ROOTS_CLI+=("$1")
        shift
      done
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKSPACE_FILE="${VSCODE_WORKSPACE_FILE:-${WORKSPACE_FILE:-}}"

python3 - "$REPO_ROOT" "$JSON" "$WORKSPACE_FILE" "${BACKLOG_ROOTS:-}" "${ROOTS_CLI[*]:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
emit_json = sys.argv[2] == "1"
workspace_file = sys.argv[3].strip()
backlog_roots_env = sys.argv[4].strip()
roots_cli = [p for p in sys.argv[5].split() if p.strip()]

header_pattern = re.compile(r"^## Issue ([A-Z]+-[0-9]{3,}) — (.+)$")
OPEN_STATUSES = {"open", "in-progress", "blocked", "slated"}


def parse_issues(path: Path):
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    issues = []
    current = None
    for line in lines:
        m = header_pattern.match(line)
        if m:
            if current:
                issues.append(current)
            current = {"header_id": m.group(1), "header_title": m.group(2), "fields": {}}
            continue
        if current is None:
            continue
        fm = re.match(r"^([A-Za-z][A-Za-z\- ]+):\s*(.*)$", line)
        if fm:
            current["fields"][fm.group(1).strip()] = fm.group(2).strip()
    if current:
        issues.append(current)
    return issues


def csv_ids(raw):
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


def dedupe(paths):
    seen = set()
    out = []
    for p in paths:
        key = str(p.resolve())
        if key not in seen:
            seen.add(key)
            out.append(p.resolve())
    return out


def discover_roots():
    if workspace_file:
        ws = Path(workspace_file).expanduser().resolve()
        if ws.exists():
            try:
                data = json.loads(ws.read_text(encoding="utf-8"))
                ws_dir = ws.parent
                roots = []
                for folder in data.get("folders", []):
                    path = folder.get("path")
                    if not path:
                        continue
                    p = Path(path)
                    if not p.is_absolute():
                        p = (ws_dir / p).resolve()
                    roots.append(p)
                if roots:
                    return dedupe(roots)
            except Exception:
                pass
    if backlog_roots_env:
        roots = [Path(p).expanduser().resolve() for p in backlog_roots_env.split(":") if p.strip()]
        if roots:
            return dedupe(roots)
    if roots_cli:
        roots = [Path(p).expanduser().resolve() for p in roots_cli]
        if roots:
            return dedupe(roots)
    return [repo_root]


roots = discover_roots()

# Build a global index of all issues across all roots: id -> status, depends
all_issues = {}  # id -> {status, depends_on, title, repo}

for root in roots:
    backlog_dir = root / "backlog"
    if not (backlog_dir / "config.toml").exists():
        continue
    for fname in ("backlog.md", "backlog-slated.md", "backlog-archive.md"):
        for issue in parse_issues(backlog_dir / fname):
            fields = issue["fields"]
            iid = fields.get("ID", issue["header_id"])
            all_issues[iid] = {
                "status": fields.get("Status", "").strip().lower(),
                "depends_on": csv_ids(fields.get("Depends on", "")),
                "title": fields.get("Title", issue["header_title"]),
                "repo": root.name,
                "effort": fields.get("Effort", ""),
            }


def resolve_id(dep_id: str) -> str:
    """Strip a cross-repo prefix (e.g. 'eposforge:EF-031' -> 'EF-031') if bare ID is in index."""
    if dep_id in all_issues:
        return dep_id
    if ":" in dep_id:
        bare = dep_id.split(":", 1)[1]
        if bare in all_issues:
            return bare
    return dep_id


def is_blocking(dep_id: str, visited: set) -> bool:
    resolved = resolve_id(dep_id)
    if resolved in visited:
        return False
    visited.add(resolved)
    entry = all_issues.get(resolved)
    if entry is None:
        return False
    if entry["status"] in OPEN_STATUSES:
        return True
    for sub in entry["depends_on"]:
        if is_blocking(sub, visited):
            return True
    return False


ready = []
for iid, entry in all_issues.items():
    if entry["status"] != "open":
        continue
    blocked = any(is_blocking(dep, set()) for dep in entry["depends_on"])
    if not blocked:
        ready.append(iid)

ready.sort()

if emit_json:
    out = [
        {
            "id": iid,
            "repo": all_issues[iid]["repo"],
            "effort": all_issues[iid]["effort"],
            "title": all_issues[iid]["title"],
        }
        for iid in ready
    ]
    print(json.dumps(out, indent=2))
else:
    if not ready:
        print("No ready items found.")
    else:
        print(f"Ready items ({len(ready)}):")
        print("")
        effort_order = {"S": 0, "M": 1, "L": 2, "XL": 3}
        ready.sort(key=lambda i: (effort_order.get(all_issues[i]["effort"], 99), i))
        for iid in ready:
            e = all_issues[iid]
            effort = f"[{e['effort']}]" if e["effort"] else ""
            print(f"  {iid} {effort} {e['title']}  ({e['repo']})")
PY
