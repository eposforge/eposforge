#!/usr/bin/env bash
set -euo pipefail

MODE="plan"
ROOTS_CLI=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      MODE="plan"
      shift
      ;;
    --regressions)
      MODE="regressions"
      KEYWORD="${2:-}"
      if [[ -z "${KEYWORD}" ]]; then
        echo "ERROR: --regressions requires a keyword" >&2
        exit 2
      fi
      shift 2
      ;;
    --graph)
      MODE="graph"
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

python3 - "$REPO_ROOT" "$MODE" "${KEYWORD:-}" "$WORKSPACE_FILE" "${BACKLOG_ROOTS:-}" "${ROOTS_CLI[*]:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
mode = sys.argv[2]
keyword = sys.argv[3]
workspace_file = sys.argv[4].strip()
backlog_roots_env = sys.argv[5].strip()
roots_cli = [p for p in sys.argv[6].split() if p.strip()]

header_pattern = re.compile(r"^## Issue ([A-Z]+-[0-9]{3,}) — (.+)$")


def parse_config(path: Path):
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    prefix_match = re.search(r'^\s*prefix\s*=\s*"([A-Z]+)"\s*$', text, re.M)
    return prefix_match.group(1) if prefix_match else ""


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
            current = {
                "header_id": m.group(1),
                "header_title": m.group(2),
                "fields": {},
                "raw": [line],
            }
            continue
        if current is None:
            continue
        current["raw"].append(line)
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
        rp = p.resolve()
        key = str(rp)
        if key in seen:
            continue
        seen.add(key)
        out.append(rp)
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
repo_sets = []
all_active = []
all_slated = []
all_archive = []

for root in roots:
    backlog_dir = root / "backlog"
    config = backlog_dir / "config.toml"
    if not config.exists():
        continue

    prefix = parse_config(config)
    active = parse_issues(backlog_dir / "backlog.md")
    slated = parse_issues(backlog_dir / "backlog-slated.md")
    archive = parse_issues(backlog_dir / "backlog-archive.md")

    for issue in active:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        all_active.append(issue)
    for issue in slated:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        all_slated.append(issue)
    for issue in archive:
        issue["repo"] = root.name
        issue["prefix"] = prefix
        all_archive.append(issue)

    repo_sets.append(root)

if not repo_sets:
    print("No backlog adapters discovered in the selected roots.")
    raise SystemExit(0)

if mode == "regressions":
    q = keyword.lower()
    hits = []
    for issue in all_archive:
        blob = "\n".join(issue["raw"]).lower()
        if q in blob:
            fields = issue["fields"]
            hits.append(
                (
                    fields.get("ID", issue["header_id"]),
                    issue["repo"],
                    fields.get("Resolved", ""),
                    fields.get("Title", issue["header_title"]),
                    fields.get("Validation", ""),
                )
            )
    if not hits:
        print(f"No archive matches for keyword: {keyword}")
        raise SystemExit(0)
    hits.sort(key=lambda x: (x[2], x[0]))
    print(f"Archive matches for '{keyword}':")
    for issue_id, repo, resolved, title, validation in hits:
        print(f"- {issue_id} [{repo}] ({resolved}) {title}")
        if validation:
            print(f"  Validation: {validation}")
    raise SystemExit(0)

if mode == "graph":
    print("Active dependency graph")
    print("")
    index = {i["fields"].get("ID", i["header_id"]): i for i in all_active}
    for issue_id in sorted(index):
        issue = index[issue_id]
        title = issue["fields"].get("Title", issue["header_title"])
        depends = csv_ids(issue["fields"].get("Depends on", ""))
        print(f"{issue_id} [{issue['repo']}] - {title}")
        if not depends:
            print("  -> (no dependencies)")
            continue
        for dep in depends:
            dep_issue = index.get(dep)
            if dep_issue:
                dep_title = dep_issue["fields"].get("Title", dep_issue["header_title"])
                print(f"  -> {dep} [{dep_issue['repo']}] - {dep_title}")
            else:
                print(f"  -> {dep} [external or archived]")
    raise SystemExit(0)

# Default: plan output
active_status_order = {"open": 0, "in-progress": 1, "blocked": 2}
effort_order = {"S": 0, "M": 1, "L": 2, "XL": 3}

active_rows = []
for issue in all_active:
    fields = issue["fields"]
    status = fields.get("Status", "")
    if status not in active_status_order:
        continue
    active_rows.append(
        {
            "repo": issue["repo"],
            "id": fields.get("ID", issue["header_id"]),
            "status": status,
            "effort": fields.get("Effort", ""),
            "surface": fields.get("Fix surface", ""),
            "title": fields.get("Title", issue["header_title"]),
            "depends": fields.get("Depends on", ""),
        }
    )

active_rows.sort(
    key=lambda r: (
        effort_order.get(r["effort"], 99),
        active_status_order.get(r["status"], 99),
        r["id"],
    )
)

print("Unified active queue")
print("")
print("| Repo | ID | Status | Effort | Surface | Title | Depends on |")
print("|---|---|---|---|---|---|---|")
for row in active_rows:
    print(
        f"| {row['repo']} | {row['id']} | {row['status']} | {row['effort']} | {row['surface']} | {row['title']} | {row['depends']} |"
    )

slated_rows = []
for issue in all_slated:
    fields = issue["fields"]
    if fields.get("Status", "") != "slated":
        continue
    slated_rows.append(
        {
            "repo": issue["repo"],
            "id": fields.get("ID", issue["header_id"]),
            "title": fields.get("Title", issue["header_title"]),
            "slated": fields.get("Slated", ""),
            "reevaluate": fields.get("Re-evaluate by", ""),
            "depends": fields.get("Depends on", ""),
        }
    )

if slated_rows:
    slated_rows.sort(key=lambda r: (r["reevaluate"], r["id"]))
    print("")
    print("Unified slated queue")
    print("")
    print("| Repo | ID | Slated | Re-evaluate by | Title | Depends on |")
    print("|---|---|---|---|---|---|")
    for row in slated_rows:
        print(
            f"| {row['repo']} | {row['id']} | {row['slated']} | {row['reevaluate']} | {row['title']} | {row['depends']} |"
        )

cross_repo = []
id_to_repo = {row["id"]: row["repo"] for row in active_rows}
for row in active_rows:
    for dep in csv_ids(row["depends"]):
        dep_repo = id_to_repo.get(dep)
        if dep_repo and dep_repo != row["repo"]:
            cross_repo.append((row["id"], row["repo"], dep, dep_repo))

if cross_repo:
    print("")
    print("Dependency-aware ordering notes")
    for issue_id, issue_repo, dep_id, dep_repo in cross_repo:
        print(f"- {issue_id} [{issue_repo}] depends on {dep_id} [{dep_repo}]")
else:
    print("")
    print("Dependency-aware ordering notes")
    print("- No cross-repo dependencies found in active issues.")
PY